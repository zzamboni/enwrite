#
# Output class for Hugo
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-04-29 20:25:46 diego>

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
    @static_dir = [ "#{@base_dir}/#{opts['static_subdir'] || 'static' }", opts['static_url'] || "" ]
    @static_subdirs = { 'image' => opts['image_subdir'] || 'img',
                        'audio' => opts['audio_subdir'] || 'audio',
                        'video' => opts['video_subdir'] || 'video',
                        'files' => opts['files_subdir'] || 'files',
                      }

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

  def set_static_dirs(note)
    @static_dirs = {}
    @static_dirs['note'] = [ "#{@static_dir[0]}/note/#{note.guid}",
                             "#{@static_dir[1]}/note/#{note.guid}" ]
    ['image', 'audio', 'video', 'files']. each do |type|
      @static_dirs[type] = [ "#{@static_dirs['note'][0]}/#{@static_subdirs[type]}",  # full path
                             "#{@static_dirs['note'][1]}/#{@static_subdirs[type]}" ]; # url path
    end
  end
  
  def delete_note(note, fname)
    set_static_dirs(note)

    if File.exist?(fname)
      msg "   This note has been deleted from Evernote, deleting its file #{fname}"
      File.delete(fname)
    end
    if Dir.exist?(@static_dirs['note'][0])
      msg "   Deleting static files for deleted note #{@static_dirs['note'][0]}"
      FileUtils.rmtree(@static_dirs['note'][0])
    end
  end

  def output_note(note)
    set_static_dirs(note)

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
      enml = ENML_utils.new(note.content, note.resources, @static_dirs)
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
