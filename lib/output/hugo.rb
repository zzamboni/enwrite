#
# Output class for Hugo
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-03-30 17:52:54 diego>

require 'output'
require 'output/filters'
require 'yaml'
require 'enml-utils'
require 'fileutils'

include Filters

class Hugo < Output
  def initialize(base_dir, opts = {})
    @base_dir = base_dir
    @content_dir = opts[:content_dir] || "#{@base_dir}/content"
    @blog_dir = opts[:blog_dir] || "#{@content_dir}/post"
    @page_dir = opts[:page_dir] || @content_dir
    @use_filters = opts[:use_filters] || true

    # These are [ realpath, urlpath ]
    @static_dir = opts[:static_dir] || [ "#{@base_dir}/static", "/" ]
    @img_dir = opts[:img_dir] || [ "#{@static_dir[0]}/img", "/img" ]
    @audio_dir = opts[:audio_dir] || [ "#{@static_dir[0]}/audio", "/audio" ]
    @video_dir = opts[:video_dir] || [ "#{@static_dir[0]}/video", "/video" ]
    @files_dir = opts[:files_dir] || [ "#{@static_dir[0]}/files", "/files" ]
  end
  
  def output_note(metadata, note)
    puts "Found note '#{note.title}'"
    verbose "Created: #{Time.at(note.created/1000)}"
    verbose "Content length: #{note.contentLength}"

    markdown = note.tagNames.include?('markdown')
    if markdown
      puts "    It has the 'markdown' tag, so I will interpret it as markdown"
      note.tagNames -= [ 'markdown' ]
    end

    frontmatter = {}
    frontmatter['title'] = note.title.gsub('#', " No. ")
    frontmatter['date'] = Time.at(note.created/1000).strftime('%F')
    frontmatter['tags'] = note.tagNames
    frontmatter['categories'] = note.tagNames
    frontmatter['description'] = ""

    base = [frontmatter['date'], note.title.gsub(/\W+/, "-")].join('-') + (markdown ? ".md" : ".html")
    fname = "#{@blog_dir}/#{base}"

    FileUtils.mkdir_p @blog_dir
    File.open(fname, "w") do |f|
      f.write(frontmatter.to_yaml)
      f.puts("---")
      f.puts
      enml = ENML_utils.new(note.content, note.resources,
                            @img_dir, @audio_dir, @video_dir, @files_dir)
      output = markdown ? enml.to_text : enml.to_html
      if @use_filters
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
