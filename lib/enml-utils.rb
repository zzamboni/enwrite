# coding: utf-8
#
# ENML Processing class
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-04-29 16:09:22 diego>

require 'digest'
require 'htmlentities'
require 'rexml/parsers/sax2parser'
require 'rexml/sax2listener'
require 'rexml/document'
require 'rexml/element'
require 'util'
include REXML

class ENML_Listener
  include REXML::SAX2Listener

  def initialize(resources, to_text, static_dirs, note_guid)
    @to_text = to_text
    @files = []
    @resources = resources || []
    @dirs = static_dirs
    @note_guid = note_guid
    @resource_index = {}
    @resources.each do |res|
      hash = Digest.hexencode(res.data.bodyHash)
      @resource_index[hash] = res
      verbose "Stored index for resource with hash #{hash}"
    end
  end
    
  def start_document
    @outdoc = Document.new
    @stack = [@outdoc]
  end

  def process_file(attributes, type, subtype)
    resource = @resource_index[attributes['hash']]
    if resource.nil?
      error "An error occurred - I don't have a resource with hash #{attributes['hash']}"
      return nil
    else
      new_file = {}
      if (!resource.attributes.nil? && !resource.attributes.fileName.nil?)
        new_file[:basename] = resource.attributes.fileName
      else
        new_file[:basename] = "#{attributes['hash']}.#{subtype}"
      end
      new_file[:fname] = "#{@dirs[type][0]}/#{attributes['hash']}/#{new_file[:basename]}"
      new_file[:url] = "#{@dirs[type][1]}/#{attributes['hash']}/#{new_file[:basename]}"
      new_file[:data] = resource.data.body
      return new_file
    end
  end
  
  def start_element(uri, localname, qname, attributes)
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
        new_file = process_file(attributes, 'image', subtype)
        if new_file
          new_elem = Element.new('img')
          new_elem.add_attributes(attributes)
          new_elem.add_attribute('src', new_file[:url])
          @files.push(new_file)
        end
      elsif attributes['type'] =~ /^(audio|video)\/(.*)/
        type = $1
        subtype = $2
        new_file = process_file(attributes, type, subtype)
        if new_file
          new_elem = Element.new(type)
          new_elem.add_attribute('controls', "1")
          new_elem.add_element 'source', { 'src' => new_file[:url], 'type' => attributes['type'] }
          new_elem.add_text "Sorry, your browser does not support the #{type} tag."
          @files.push(new_file)
        end
      elsif attributes['type'] =~ /^(\S+)\/(\S+)/
        type = $1
        subtype = $2
        new_file = process_file(attributes, 'files', subtype)
        if new_file
          new_elem = Element.new('a')
          new_elem.add_attribute('href', new_file[:url])
          new_elem.add_text(new_file[:basename])
          @files.push(new_file)
        end
      else
        error "Sorry, I don't know how to handle attachments of this type: #{attributes['type']}"
      end
    else
      new_elem = Element.new(localname)
      new_elem.add_attributes(attributes)
    end
    @stack.push(new_elem)
  end
  
  def end_element(uri, localname, qname)
    new_elem = @stack.pop
    @stack[-1].add_element(new_elem) unless new_elem.nil?
  end
  
  def characters(text)
    @stack[-1].add_text(text)
  end

  def end_document
    @output = ""
    @stack[-1].write(@output)
    decoder = HTMLEntities.new
    # One pass of entity decoding for HTML output...
    @output = decoder.decode(@output)
    if @to_text
      # Clean up some tags, extra empty lines, prettyfied characters, etc.
      @output.gsub!(/<\/?span[^>]*>/, '')
      @output.gsub!(/\t*<div[^>]*>/, '')
      @output.gsub!(/<\/div>/, "\n")
      @output.gsub!(/^\s+$/, '')
      @output.gsub!(/\n+/, "\n")
      @output.gsub!(/<br[^>]*\/>/, "\n")
      @output.gsub!(/“/, '"')
      @output.gsub!(/”/, '"')
      @output.gsub!(/‘/, "'")
      @output.gsub!(/’/, "'")
      @output.gsub!(/\u{a0}/, " ")  # Unicode non-breaking space
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
  def initialize(text, resources = nil, static_dirs = {}, note_guid = "")
    @text = text or ""
    @resources = resources or []
    @static_dirs = static_dirs
    @note_guid = note_guid
  end

  def to_html(to_text=false)
    parser = Parsers::SAX2Parser.new( @text )
    debug "to_html input text:"
    debug "-----"
    debug @text
    debug "-----"
    listener = ENML_Listener.new(@resources, to_text, @static_dirs, @note_guid)
    parser.listen(listener)
    parser.parse
    @files = listener.files
    debug "to_html output:"
    debug listener.output
    debug "-----"
    return listener.output
  end

  def to_text
    return to_html(true)
  end
  
  def resource_files
    return @files
  end
end
