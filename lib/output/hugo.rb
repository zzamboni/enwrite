#
# Output class for Hugo
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-04-16 23:03:53 diego>

require 'output'
require 'output/filters'
require 'enml-utils'
require 'fileutils'

include Filters

class Hugo < Output
  def initialize(base_dir, opts = {})
    @base_dir = base_dir
    #    @content_dir = opts[:content_dir] || "#{@base_dir}/content"
    #    @blog_dir = opts[:blog_dir] || "#{@content_dir}/post"
    #    @page_dir = opts[:page_dir] || @content_dir
    @use_filters = opts[:use_filters] || true

    # These are [ realpath, urlpath ]
    @static_dir = opts[:static_dir] || [ "#{@base_dir}/static", "/" ]
    @img_dir = opts[:img_dir] || [ "#{@static_dir[0]}/img", "/img" ]
    @audio_dir = opts[:audio_dir] || [ "#{@static_dir[0]}/audio", "/audio" ]
    @video_dir = opts[:video_dir] || [ "#{@static_dir[0]}/video", "/video" ]
    @files_dir = opts[:files_dir] || [ "#{@static_dir[0]}/files", "/files" ]

    # Tag-to-type map
    @tag_to_type = { "default" => "post/",
                     "post" => "post/",
                     "page" => "" }
    @tag_to_type_order = [ "post", "page", "default" ]

    # Markdown tag
    @markdown_tag = "markdown"

    # Command to run hugo
    @hugo_cmd = "hugo"
  end

  def output_note(note)
    msg "Found note '#{note.title}'"
    verbose "Created: #{Time.at(note.created/1000)}" if note.created
    verbose "Deleted: #{Time.at(note.deleted/1000)}" if note.deleted
    verbose "Content length: #{note.contentLength}"  if note.contentLength

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

    # Run hugo to create the file, then read it back it to update the front matter
    # with our tags.
    # We run "hugo new" also for deleted notes so that hugo gives us the filename
    # to delete.
    fname = nil
    frontmatter = nil
    Dir.chdir(@base_dir) do
      date = Time.at(note.created/1000).strftime('%F')
      # Force -f yaml because it's so much easier to process
      while true
        output = %x(#{@hugo_cmd} new -f yaml '#{type}#{date}-#{note.title}.#{(markdown ? "md" : "html")}')
        if output =~ /^(.+) created$/
          # Get the filename
          fname = $1
          # If the post has been deleted, simply remove the file
          if note.deleted
            msg "   This note has been deleted from Evernote, removing its file #{fname}"
            File.delete(fname)
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
          fname = $1
          # If the file existed already, remove it...
          File.delete(fname)
          if note.deleted
            # ...and if the post has been deleted, leave it removed
            msg "   This note has been deleted from Evernote, removing its file #{fname}"
            return
          else
            # ...otherwise regenerate it
            verbose "   File existed already, deleting and regenerating"
            redo
          end
        else
          error "   Hugo returned unknown output when trying to create this post - skipping it: #{output}"
          return
        end
      end
    end

    verbose "Updated frontmatter: #{frontmatter.to_s}"
    
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
  end
end
