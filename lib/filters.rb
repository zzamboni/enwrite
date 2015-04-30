# coding: utf-8
require 'htmlentities'

module Filters

  def run_filters(text)
    newtext = text
    text.scan(/(\[(\w+)([^\]]*)\])/) do |m|
      match = m[0]
      debug "match = #{match}"
      filter = m[1]
      args = m[2]
      if Filters.method_defined?("filter_#{filter}")
        fn=Filters.method("filter_#{filter}")
        arg = {}
        args = HTMLEntities.new.decode(args)
        debug "args = #{args}"
        args.scan(/\b(\w+)=["“]([^"]*)["”]/) { |a|
          arg[a[0]] = a[1]
        }
        verbose "Calling filter_#{filter} with args #{arg}"
        result = fn.(arg)
        if not result.nil?
          newtext = newtext.gsub(match, result)
        end
      else
        # We only produce this message in verbose mode because it gets triggered
        # every time [some text in brackets] is used
        warn("Warning: nonexistent filter #{filter} used, leaving text as is") if $enwrite_verbose
      end
    end
    debug "After running filters:"
    debug newtext
    return newtext
  end
  
  def filter_youtube(args)
    if args.include?('url')
      args['src'] = args['url']
      args.delete('url')
    elsif args.include?('id')
      args['src'] = "https://www.youtube.com/embed/#{args['id']}"
    end
    if args['src'].nil?
      return nil
    end
    args['src'].gsub!(/\/watch\?v=/, "/embed/")
    return "<iframe "+args.each.map{ |k,v| "#{k}=\"#{v}\"" }.join(" ")+"></iframe>"
  end

  def filter_gist(args)
    if args.include?('url')
      args['src'] = args['url']
      args.delete('url')
    end
    if args['src'].nil?
      return nil
    end
    if not args['src'] =~ /\.js$/
      args['src'] += ".js"
    end
    return "<script "+args.each.map{ |k,v| "#{k}=\"#{v}\"" }.join(" ")+"></script>"
  end
end
