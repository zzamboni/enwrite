#!/usr/bin/env ruby

#
# enwrite - power a web site using Evernote
#
# Diego Zamboni, March 2015

require 'rubygems'

require "digest/md5"
require 'evernote-thrift'
require 'evernote-utils'
require "optparse"
require "ostruct"
require 'util'
require 'yaml'
require 'deep_merge'
require 'tempfile'

class Enwrite
  PLUGINS = %w[hugo]
  module Version
    MAJOR = 0
    MINOR = 2
    PATCH = 2

    STRING = [MAJOR, MINOR, PATCH].compact.join('.')
  end
  
  def self.run

    options = OpenStruct.new
    options.removetags = []
    options.verbose = false
    options.debug = false
    options.outputplugin = 'hugo'
    options.configtag = '_enwrite_config'
    options.filestagprefix = '_enwrite_files'

    opts = OptionParser.new do |opts|
      def opts.version_string
        "Enwrite v#{Enwrite::Version::STRING}"
      end
      
      opts.banner = "#{opts.version_string}\n\nUsage: #{$0} [options] (at least one of -n or -s has to be specified)"

      def opts.show_usage
        puts self
        exit
      end

      def opts.show_version
        puts version_string
        exit
      end

      opts.separator "\nSearch options:"
      opts.on("-n", "--notebook NOTEBOOK",
              "Process notes from specified notebook.") do |notebook|
        options.notebook = notebook
      end
      opts.on("-t", "--tag TAG",
              "Process only notes that have this tag",
              "within the given notebook.") do |tag|
        options.tag = tag
      end
      opts.on("--remove-tags [t1,t2,t3]", Array,
              "List of tags to remove from output posts.",
              "If no argument given, defaults to --tag.") do |removetags|
        options.removetags = removetags || [options.tag]
      end
      opts.on("-s", "--search SEARCHEXP",
              "Process notes that match given search",
              "expression. If specified, --notebook",
              "and --tag are ignored.") do |searchexp|
        options.searchexp = searchexp
        options.tag = nil
        options.notebook = nil
      end
      opts.separator 'Output options:'
      opts.on("-p", "--output-plugin PLUGIN", PLUGINS,
              "Output plugin to use (Valid values: #{PLUGINS.join(', ')})") do |plugin|
        options.outputplugin = plugin
      end
      opts.on("-o", "--output-dir OUTDIR",
              "Base dir of hugo output installation") do |outdir|
        options.outdir = outdir
      end
      opts.on("--rebuild-all",
              "Process all notes that match the given",
              "conditions (normally only updated notes",
              "are processed)") { options.rebuild_all = true }
      opts.separator 'Other options:'
      opts.on("--auth [TOKEN]",
              "Force Evernote reauthentication (will",
              "happen automatically if needed). Use",
              "TOKEN if given, otherwise get one",
              "interactively.") do |forceauth|
        options.forceauth = true
        options.authtoken = forceauth
      end
      opts.on("--config-tag TAG",
              "Specify tag to determine config notes",
              "(default: #{options.configtag})") { |conftag|
        options.configtag = conftag
      }
      opts.on_tail("-v", "--verbose", "Verbose mode") { options.verbose=true }
      opts.on_tail("-d", "--debug", "Debug output mode") {
        options.debug=true
        options.verbose=true
      }
      opts.on_tail("--version", "Show version") { opts.show_version }
      opts.on_tail("-h", "--help", "Shows this help message") { opts.show_usage }
    end

    opts.parse!

    begin
      eval "require 'output/#{options.outputplugin}'"
    rescue LoadError
      error "There was an error loading output module '#{plugin}': #{e.to_s}"
      exit 1
    end

    $enwrite_verbose = options.verbose
    $enwrite_debug = options.debug

    verbose("Options: " + options.to_s)

    if not (options.notebook or options.searchexp or options.forceauth)
      error "You have to specify at least one of --notebook, --search or --auth"
      exit(1)
    end
    exps = [ options.searchexp ? options.searchexp : nil,
             options.notebook ? "notebook:#{options.notebook}" : nil,
             options.tag ? "tag:#{options.tag}" : nil,
           ].reject(&:nil?)
    searchexp = exps.join(' ')

    verbose "Output dir: #{options.outdir}"
    verbose "Search expression: #{searchexp}"

    begin
      
      # Initialize Evernote access
      Evernote_utils.init(options.forceauth, options.authtoken)

      if not searchexp # Only --auth was specified
        exit 0
      end
      
      updatecount_index = "updatecount_#{searchexp}"
      latestUpdateCount = config(updatecount_index, 0)
      if options.rebuild_all
        msg "Processing ALL notes (--rebuild-all)."
        latestUpdateCount = 0
      end

      verbose "Latest stored update count for #{searchexp}: #{latestUpdateCount}"

      currentState = Evernote_utils.noteStore.getSyncState(Evernote_utils.authToken)
      currentUpdateCount = currentState.updateCount

      verbose "Current update count for the account: #{currentUpdateCount}"

      if (currentUpdateCount > latestUpdateCount)
        msg "Checking updated Evernote contents..."

        # There are new notes, doesn't necessarily mean any of them are withing the
        # selected content, so we keep track of whether we actually produce any updates
        # in the output.
        something_updated = false

        filter = Evernote::EDAM::NoteStore::NoteFilter.new
        filter.words = searchexp
        filter.order = Evernote::EDAM::Type::NoteSortOrder::UPDATE_SEQUENCE_NUMBER
        filter.ascending = false

        spec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new
        spec.includeTitle = true
        spec.includeCreated = true
        spec.includeTagGuids = true
        spec.includeContentLength = true
        spec.includeUpdateSequenceNum = true
        spec.includeDeleted = true

        results = Evernote_utils.noteStore.findNotesMetadata(Evernote_utils.authToken,
                                                             filter,
                                                             0,
                                                             Evernote::EDAM::Limits::EDAM_USER_NOTES_MAX,
                                                             spec)

        # Get also deleted notes so we can remove from the blog
        filter.inactive = true
        delresults = Evernote_utils.noteStore.findNotesMetadata(Evernote_utils.authToken,
                                                                filter,
                                                                0,
                                                                Evernote::EDAM::Limits::EDAM_USER_NOTES_MAX,
                                                                spec)

        # Go through the list looking for config notes, parse them and remove
        # them from the list
        enwriteconfig = { 'hugo' => {
                            'base_dir' => options.outdir,
                            'rebuild_all' => options.rebuild_all,
                          },
                        }

        if Evernote_utils.tags.include?(options.configtag)
          config_tag_guid = Evernote_utils.tags[options.configtag].guid
          results.notes.select { |note|
            note.tagGuids.include?(config_tag_guid)
          }.each { |confignotemd|
            msg "Found config note '#{confignotemd.title}'"
            confignote = Evernote_utils.getWholeNote(confignotemd)
            enml = ENML_utils.new(confignote.content)
            configtext = enml.to_text
            debug "   Config note text: '#{configtext}'"
            configyaml = YAML.load(configtext)
            debug "   Config note YAML: #{configyaml}"
            enwriteconfig.deep_merge!(configyaml)
            debug "   enwriteconfig = #{enwriteconfig}"
            results.notes.delete(confignotemd)
            results.totalNotes -= 1
          }
        end
        verbose "Final enwrite config: #{enwriteconfig}"

        files_tag = "#{options.filestagprefix}_#{options.outputplugin}"

        if Evernote_utils.tags.include?(files_tag)
          files_tag_guid = Evernote_utils.tags[files_tag].guid
          results.notes.select { |note|
            note.tagGuids.include?(files_tag_guid) &&
              note.updateSequenceNum > latestUpdateCount
          }.each { |filesnotemd|
            msg "Found files note '#{filesnotemd.title}'"
            filesnote = Evernote_utils.getWholeNote(filesnotemd)
            enml = ENML_utils.new(filesnote.content, filesnote.resources)
            files = enml.resource_files
            Dir.chdir("#{options.outdir}")
            files.each do |file|
              case
              when file[:basename] =~ /\.tar.gz$/
                f = Tempfile.new('enwrite')
                begin
                  verbose "   Saving file #{file[:basename]} to #{f.path}"
                  f.write(file[:data])
                  f.close
                  verbose "   Unpacking file #{f.path} with tar"
                  ok = system("tar zxf #{f.path}")
                  unless ok
                    error "   An error occurred when unpacking #{f.path}"
                  end
                ensure
                  f.close
                  f.unlink
                end
              else
                open("#{options.outdir}/#{file[:basename]}", "w") do |f|
                  verbose "   Saving file #{f.path}"
                  f.write(file[:data])
                end
              end
            end
            something_updated = true
            results.notes.delete(filesnotemd)
            results.totalNotes -= 1
          }
        end

        debug "Evaluating: #{options.outputplugin.capitalize}.new(enwriteconfig[options.outputplugin])"
        writer = eval "#{options.outputplugin.capitalize}.new(enwriteconfig[options.outputplugin])"
        
        (results.notes + delresults.notes).select {
          |note| note.updateSequenceNum > latestUpdateCount
        }.sort_by {
          |note| note.updateSequenceNum
        }.each do |metadata|
          verbose "######################################################################"
          note = Evernote_utils.getWholeNote(metadata)
          note.tagNames = note.tagNames - options.removetags
          # This either creates or deletes posts as appropriate
          writer.output_note(note)
          something_updated = true
        end
        # Persist the latest updatecount for next time
        setconfig(updatecount_index, currentUpdateCount)
      end

      if something_updated
        exit 0
      else
        msg "No updated notes that match #{searchexp}"
        exit 1
      end
    rescue Evernote::EDAM::Error::EDAMUserException => e
      #the exceptions that come back from Evernote are hard to read, but really important to keep track of
      msg = "Caught an exception from Evernote trying to create a note.  #{Evernote_utils.translate_error(e)}"
      raise msg
    rescue Evernote::EDAM::Error::EDAMSystemException => e
      #the exceptions that come back from Evernote are hard to read, but really important to keep track of
      msg = "Caught an exception from Evernote trying to create a note.  #{Evernote_utils.translate_error(e)}"
      raise msg
    end
  end
end
