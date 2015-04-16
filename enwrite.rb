#!/usr/bin/env ruby

#
# enwrite - power a web site using Evernote
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-04-16 14:53:49 diego>

require 'rubygems'
require 'bundler/setup'

require "digest/md5"
require 'evernote-thrift'
require 'output/hugo'
require 'evernote-utils'
require "optparse"
require "ostruct"
require 'util'

$enwrite_version = "0.0.1"

options = OpenStruct.new
options.removetags = []
options.verbose = false

opts = OptionParser.new do |opts|
  def opts.version_string
    "Enwrite v#{$enwrite_version}"
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

  opts.separator ''
  opts.on("-n", "--notebook NOTEBOOK",
          "Process notes from specified notebook.") do |notebook|
    options.notebook = notebook
  end
  opts.on("-t", "--tag TAG",
          "Process only notes that have this tag",
          " within the given notebook.") do |tag|
    options.tag = tag
  end
  opts.on("-s", "--search SEARCHEXP",
          "Process notes that match given search",
          " expression. If specified, --notebook",
          " and --tag are ignored.") do |searchexp|
    options.searchexp = searchexp
    options.tag = nil
    options.notebook = nil
  end
  opts.on("-o", "--output-dir OUTDIR",
          "Base dir of hugo output installation") do |outdir|
    options.outdir = outdir
  end
  opts.on("--remove-tags [t1,t2,t3]", Array,
          "List of tags to remove from output posts.",
          "If no argument given, defaults to --tag.") do |removetags|
    options.removetags = removetags || [options.tag]
  end
  opts.on("--auth [TOKEN]",
          "Force Evernote reauthentication (will happen automatically if needed).",
          "If TOKEN is given, use it, otherwise get one interactively.") do |forceauth|
    options.forceauth = true
    options.authtoken = forceauth
  end
  opts.on("--rebuild-all",
          "Process all notes that match the given conditions (normally only updated",
          "notes are processed)") { options.rebuild_all = true }
  opts.on_tail("-v", "--verbose", "Verbose mode") { options.verbose=true }
  opts.on_tail("--version", "Show version") { opts.show_version }
  opts.on_tail("-h", "--help", "Shows this help message") { opts.show_usage }
end

opts.parse!

$enwrite_verbose = options.verbose

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
    msg "Reading updated notes from #{searchexp}"

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
    
    hugo = Hugo.new(options.outdir)
    
    (results.notes + delresults.notes).select {
      |note| note.updateSequenceNum > latestUpdateCount
    }.sort_by {
      |note| note.updateSequenceNum
    }.each do |metadata|
      verbose "######################################################################"
      note = Evernote_utils.getWholeNote(metadata)
      note.tagNames = note.tagNames - options.removetags
      # This either creates or deletes posts as appropriate
      hugo.output_note(note)
    end
    # Persist the latest updatecount for next time
    setconfig(updatecount_index, currentUpdateCount)

    exit 0
  else
    msg "No updated notes for #{searchexp}"
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

