#
# ENML Processing class
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-03-29 18:19:09 diego>

require 'digest'
require 'htmlentities'
require 'rexml/parsers/sax2parser'
require 'rexml/sax2listener'
require 'rexml/document'
require 'rexml/element'
include REXML

class ENML_Listener
  include REXML::SAX2Listener

  def initialize(resources, to_text, img_dir, audio_dir, video_dir, files_dir)
    @to_text = to_text
    @files = []
    @resources = resources || []
    @img_dir = img_dir
    @audio_dir = audio_dir
    @video_dir = video_dir
    @files_dir = files_dir
    @resource_index = {}
    @resources.each do |res|
      hash = Digest.hexencode(res.data.bodyHash)
      @resource_index[hash] = res
      puts "Stored index for resource with hash #{hash}"
    end
  end
    
  def start_document
    @outdoc = Document.new
    @stack = [@outdoc]
  end
  
  def start_element(uri, localname, qname, attributes)
    # $stderr.puts "Found start: #{uri}, #{localname}, #{qname}, #{attributes}"
    new_elem = nil
    if localname == 'en-note'
      # Convert <en-note> to <span>
      new_elem = Element.new('span')
      new_elem.add_attributes(attributes)
    elsif localname == 'en-todo'
      unless @to_text
        new_elem = Element.new('input')
        new_elem.add_attribute('type', 'checkbox')
        if attributes and attributes['checked'] == 'true'
          new_elem.add_attribute('checked', 'checked')
        end
      else
        if attributes and attributes['checked'] == 'true'
          @stack[-1].add_text("[x] ")
        else
          @stack[-1].add_text("[ ] ")
        end
      end
    elsif localname == 'en-media'
      if attributes['type'] =~ /^image\/(.+)/
        subtype = $1
        new_elem = Element.new('img')
        resource = @resource_index[attributes['hash']]
        if resource.nil?
          puts "An error occurred - I don't have a resource with hash #{attributes['hash']}"
        else
          new_file = {}
          if (!resource.attributes.nil? && !resource.attributes.fileName.nil?)
            new_file[:basename] = resource.attributes.fileName
          else
            new_file[:basename] = "#{attributes['hash']}.#{subtype}"
          end
          new_file[:fname] = "#{@img_dir[0]}/#{new_file[:basename]}"
          new_file[:url] = "#{@img_dir[1]}/#{new_file[:basename]}"
          new_file[:data] = resource.data.body
          new_elem.add_attributes(attributes)
          new_elem.add_attribute('src', new_file[:url])

          @files.push(new_file)
        end
      elsif attributes['type'] =~ /^audio\//
        puts "Don't know how to handle audio files yet"
      elsif attributes['type'] =~ /^video\//
        puts "Don't know how to handle video files yet"
      else
        puts "Don't know how to handle other files yet"
      end
    else
      new_elem = Element.new(localname)
      new_elem.add_attributes(attributes)
    end
    @stack.push(new_elem)
  end
  
  def end_element(uri, localname, qname)
    # $stderr.puts "Found   end: #{uri}, #{localname}, #{qname}"
    new_elem = @stack.pop
    @stack[-1].add_element(new_elem) unless new_elem.nil?
  end
  
  def characters(text)
    # $stderr.puts "Found '#{text}'"
    @stack[-1].add_text(text)
  end

  def end_document
    # $stderr.puts "End of document! Here's what I collected:"
    @output = ""
    @stack[-1].write(@output)
    decoder = HTMLEntities.new
    # One pass of entity decoding for HTML output...
    @output = decoder.decode(@output)
    if @to_text
      @output.gsub!(/<\/?span[^>]*>/, '')
      @output.gsub!(/\t*<div[^>]*>/, '')
      @output.gsub!(/<\/div>/, "\n")
      @output.gsub!(/^\s+$/, '')
      @output.gsub!(/\n+/, "\n")
      @output.gsub!(/<br[^>]*\/>/, "\n")
      # ...two passes of decoding for text output.
      @output = decoder.decode(@output)
    end
  end

  def output
    @output
  end
  def files
    @files
  end
end

class ENML_utils
  def initialize(text, resources = nil, img_dir, audio_dir, video_dir, files_dir)
    @text = text or ""
    @resources = resources or []
    @img_dir = img_dir
    @audio_dir = audio_dir
    @video_dir = video_dir
    @files_dir = files_dir
  end

  def to_html(to_text=false)
    parser = Parsers::SAX2Parser.new( @text )
    puts "to_html input text:"
    puts "-----"
    puts @text
    puts "-----"
    listener = ENML_Listener.new(@resources, to_text, @img_dir, @audio_dir, @video_dir, @files_dir)
    parser.listen(listener)
    parser.parse
    @files = listener.files
    puts "to_html output:"
    puts listener.output
    puts "-----"
    return listener.output
  end

  def to_text
    return to_html(true)
  end
  
  def resource_files
    return @files
  end
end
