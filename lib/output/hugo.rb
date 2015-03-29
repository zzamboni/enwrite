#
# Output class for Hugo
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-03-29 00:50:53 diego>

require 'output'
require 'yaml'
require 'enml-utils'

class Hugo < Output
  def initialize(base_dir)
    @base_dir = base_dir
    @content_dir = "#{@base_dir}/content"
    @blog_dir = "#{@content_dir}/post"
    @page_dir = @content_dir
  end
  
  def output_note(metadata, note)
    puts "Found note '#{note.title}'"
    puts "Created: #{Time.at(note.created/1000)}"
    puts "Content length: #{note.contentLength}"

    frontmatter = {}
    frontmatter['title'] = note.title
    frontmatter['date'] = Time.at(note.created/1000).strftime('%F')
    frontmatter['tags'] = note.tagNames
    frontmatter['categories'] = note.tagNames
    frontmatter['description'] = ""

    base = [frontmatter['date'], note.title.gsub(/\W+/, "-")].join('-') + ".md"
    fname = "#{@blog_dir}/#{base}"
    File.open(fname, "w") do |f|
      f.write(frontmatter.to_yaml)
      f.puts("---")
      f.puts
      enml = ENML_utils.new(note.content, note.resources)
      f.puts(enml.to_html)
    end

    puts "Wrote file #{fname}"
  end
end
