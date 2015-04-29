#
# Output class for Hugo
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-04-29 15:11:10 diego>

require 'output'
require 'output/filters'
require 'enml-utils'
require 'fileutils'
require 'yaml/store'
require 'digest'

include Filters

class Hugo < Output
  def initialize(opts = {})
    @opts = opts
    @base_dir = opts['base_dir']
    unless @base_dir
      error "The 'base_dir' option of the Hugo plugin must be set!"
    end
    @use_filters = opts['use_filters'] || true
    @rebuild_all = opts['rebuild_all'] || false

    # Persistent store for this base_dir
    datadir = "#{@base_dir}/data"
    FileUtils.mkdir_p datadir
    @config_store = YAML::Store.new("#{datadir}/enwrite_data.yaml")

    # Initialize GUID-to-filename map if needed
    @config_store.transaction { @config_store[:note_files] = {} unless @config_store[:note_files] }
    
    # These are [ realpath, urlpath ]
    @static_dir = opts['static_dir'] || [ "#{@base_dir}/static", "/" ]
    @img_dir = opts['img_dir'] || [ "#{@static_dir[0]}/img", "/img" ]
    @audio_dir = opts['audio_dir'] || [ "#{@static_dir[0]}/audio", "/audio" ]
    @video_dir = opts['video_dir'] || [ "#{@static_dir[0]}/video", "/video" ]
    @files_dir = opts['files_dir'] || [ "#{@static_dir[0]}/files", "/files" ]

    # Tag-to-type map
    @tag_to_type = opts['tag_to_type'] || { "default" => "post/",
                                            "post" => "post/",
                                            "page" => "" }
    @tag_to_type_order = opts['tag_to_type_order'] || [ "post", "page", "default" ]

    @tag_to_type_order.each { |type|
      @tag_to_type[type] = "" unless @tag_to_type.include?(type)
      @tag_to_type[type] = "" if @tag_to_type[type].nil?
    }
    
    # Markdown tag
    @markdown_tag = opts['markdown_tag'] || "markdown"

    # Command to run hugo
    @hugo_cmd = opts['hugo_cmd'] || "hugo"
  end

  def delete_note(note, fname)
    if File.exist?(fname)
      msg "   This note has been deleted from Evernote, deleting its file #{oldfile}"
      File.delete(fname)
    end
    note.resources.each do |r|
      if r.mime =~ /(\S+)\/(\S+)/
        type = $1
        subtype = $2
        hash = Digest.hexencode(r.data.bodyHash)
        basename = if (!r.attributes.nil? && !r.attributes.fileName.nil?)
                     r.attributes.fileName
                   else
                     "#{hash}.#{subtype}"
                   end
        dir = case type
              when 'image'
                @img_dir[0]
              when 'audio'
                @audio_dir[0]
              when 'video'
                @video_dir[0]
              else
                @files_dir[0]
              end
        rname = "#{dir}/#{hash}/#{basename}"
        verbose "Checking if resource file #{rname} needs to be deleted."
        if File.exist?(rname)
          msg "   Removing resource file #{rname}"
          File.delete(rname)
        end
      end
    end
  end
  
  def output_note(note)
    msg "Found note '#{note.title}'"
    verbose "Created: #{Time.at(note.created/1000)}" if note.created
    verbose "Deleted: #{Time.at(note.deleted/1000)}" if note.deleted
    verbose "Content length: #{note.contentLength}"  if note.contentLength
    verbose "Clipped from: #{note.attributes.sourceURL}" if note.attributes.sourceURL

    markdown = note.tagNames.include?(@markdown_tag)
    if markdown
      msg "   It has the '#{ @markdown_tag }' tag, so I will interpret it as markdown"
      note.tagNames -= [ @markdown_tag ]
    end

    type = nil
    # Detect the type of post according to its tags
    @tag_to_type_order.each do |tag|
      if note.tagNames.include?(tag) or tag == "default"
        type = @tag_to_type[tag]
        break
      end
    end
    if type.nil?
      error "   ### I couldn't determine the type for this post - skipping it"
      return
    end

    # Determine if we should include the page in the main menu
    inmainmenu = note.tagNames.include?('_mainmenu')
    if inmainmenu
      note.tagNames -= [ '_mainmenu' ]
    end

    # Get our note GUID-to-filename map
    note_files = config(:note_files, {}, @config_store)
    
    # Determine the name I would assign to this note when published to Hugo
    date = Time.at(note.created/1000).strftime('%F')
    post_filename = "#{type}#{date}-#{note.title}.#{markdown ? 'md' : 'html'}"
    # Do we already have a post for this note (by GUID)? If so, we remove the
    # old file since it will be regenerated anyway, which also takes care of the
    # case when the note was renamed and the filename will change, to avoid
    # post duplication. If the note has been deleted, we just delete the
    # old filename and stop here.
    oldfile = note_files[note.guid]
    if oldfile
      verbose "   I already had a file for note #{note.guid}, removing #{oldfile}"
      File.delete(oldfile) if File.exist?(oldfile)
      note_files.delete(note.guid)
      setconfig(:note_files, note_files, @config_store)
      if note.deleted
        delete_note(note, oldfile)
        return
      end
    end
    
    # Run hugo to create the file, then read it back it to update the front matter
    # with our tags.
    # We run "hugo new" also for deleted notes so that hugo gives us the filename
    # to delete.
    fname = nil
    frontmatter = nil
    Dir.chdir(@base_dir) do
      # Force -f yaml because it's so much easier to process
      while true
        output = %x(#{@hugo_cmd} new -f yaml '#{post_filename}')
        if output =~ /^(.+) created$/
          # Get the full filename as reported by Hugo
          fname = $1
          if note.deleted
            delete_note(note, fname)
            return
          end
          # Load the frontmatter
          frontmatter = YAML.load_file(fname)
          # Update title because Hugo gets it wrong sometimes depending on the characters in the title, and to get rid of the date we put in the filename
          frontmatter['title'] = note.title
          # Fix the date to the date when the note was created
          frontmatter['date'] = date
          # Update tags, for now set categories to the same
          frontmatter['tags'] = note.tagNames
          frontmatter['categories'] = note.tagNames
          # Set slug to work around https://github.com/spf13/hugo/issues/1017
          frontmatter['slug'] = note.title.downcase.gsub(/\W+/, "-").gsub(/^-+/, "").gsub(/-+$/, "")
          # Set main menu tag if needed
          frontmatter['menu'] = 'main' if inmainmenu
          break
        elsif output =~ /ERROR: \S+ (.+) already exists/
          # Get the full filename as reported by Hugo
          fname = $1
          # If the file existed already, remove it and regenerate it
          File.delete(fname)
          if note.deleted
            delete_note(note, fname)
            return
          end
          # This shouldn't happen due to the index check above
          unless @rebuild_all
            error "   I found a file that should not be there (#{fname}). This might indicate"
            error "   an inconsistency in my internal note-to-file map. Please re-run with"
            error "   --rebuild-all to regenerate it. I am deleting the file and continuing"
            error "   for now, but please review the results carefully."
          end
          redo
        else
          error "   Hugo returned unknown output when trying to create this post - skipping it: #{output}"
          return
        end
      end
    end

    debug "Updated frontmatter: #{frontmatter.to_s}"
    
    File.open(fname, "w") do |f|
      f.write(frontmatter.to_yaml)
      f.puts("---")
      f.puts
      enml = ENML_utils.new(note.content, note.resources,
                            @img_dir, @audio_dir, @video_dir, @files_dir)
      output = markdown ? enml.to_text : enml.to_html
      if @use_filters
        verbose "Running filters on text"
        output = run_filters(output)
      end
      if note.attributes.sourceURL
        f.puts(%(<p class="clip-attribute">via <a href="#{note.attributes.sourceURL}">#{note.attributes.sourceURL}</a></p>))
      end
      f.puts(output)
      enml.resource_files.each do |resfile|
        FileUtils.mkdir_p File.dirname(resfile[:fname])
        File.open(resfile[:fname], "w") do |r|
          r.write(resfile[:data])
        end
        verbose "Wrote file #{resfile[:fname]}"
      end
    end

    verbose "Wrote file #{fname}"
    note_files[note.guid] = fname
    setconfig(:note_files, note_files, @config_store)
    
  end
end
