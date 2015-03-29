#
# ENML Processing class
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-03-29 00:50:03 diego>

require 'rexml/parsers/sax2parser'
require 'rexml/sax2listener'
require 'rexml/document'
require 'rexml/element'
include REXML

class ENML_Listener
  include REXML::SAX2Listener

  def start_document
    @outdoc = Document.new
    @stack = [@outdoc]
  end
  
  def start_element(uri, localname, qname, attributes)
    # $stderr.puts "Found start: #{uri}, #{localname}, #{qname}, #{attributes}"
    if localname == 'en-note'
      # Convert <en-note> to <span>
      new_elem = Element.new('div')
      new_elem.add_attributes(attributes)
    elsif localname == 'en-todo'
      new_elem = Element.new('input')
      if attributes and attributes{'checked'} == 'true'
        new_elem.add_attribute('checked', 'checked')
      end
    elsif localname == 'en-media'
      # For now we just copy it, TBD later
      new_elem = Element.new(localname)
      new_elem.add_attributes(attributes)
    else
      new_elem = Element.new(localname)
      new_elem.add_attributes(attributes)
    end
    @stack.push(new_elem)
  end
  
  def end_element(uri, localname, qname)
    # $stderr.puts "Found   end: #{uri}, #{localname}, #{qname}"
    new_elem = @stack.pop
    @stack[-1].add_element(new_elem)
  end
  
  def characters(text)
    # $stderr.puts "Found '#{text}'"
    @stack[-1].add_text(text)
  end

  def end_document
    # $stderr.puts "End of document! Here's what I collected:"
    @output = ""
    @stack[-1].write(@output, 0)
  end

  def output
    @output
  end
end

class ENML_utils
  def initialize(text = "", resources = nil)
    @text = text or ""
    @resources = resources or []
  end

  def to_html
    parser = Parsers::SAX2Parser.new( @text )
    listener = ENML_Listener.new
    parser.listen(listener)
    parser.parse
    return listener.output
  end
end

#enml = ENML_utils.new(File.new( ARGV[0] ).read)
#puts enml.to_html
