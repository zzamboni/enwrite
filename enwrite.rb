#!/usr/bin/env ruby

#
# enwrite - power a web site using Evernote
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-03-29 00:50:24 diego>

require "digest/md5"
require 'evernote-thrift'
require 'output/hugo'
require 'evernote-utils'
require "optparse"
require "ostruct"

options = OpenStruct.new
options.outdir = "./output"
options.tag = 'published'

opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [-n notebook | -e searchexp ] -o outdir"

  def opts.show_usage
    puts self
    exit
  end

  opts.separator ''
  opts.on("-n NOTEBOOK", "--notebook",
          "Process notes from specified notebook.") do |notebook|
    options.notebook = notebook
  end
  opts.on("-t TAG", "--tag",
          "Process notes that have the specified tag.") do |tag|
    options.tag = tag
  end
  opts.on("-s SEARCHEXP", "--search",
          "Process notes that match specified search expression.") do |searchexp|
    options.searchexp = searchexp
    options.tag = nil
    options.notebook = nil
  end
  opts.on("-o OUTDIR", "--output-dir",
          "Base dir of hugo output installation.") do |outdir|
    options.outdir = outdir
  end
  opts.on("-h", "--help", "Shows this help message") { opts.show_usage }
end

opts.parse!

if not (options.notebook or options.searchexp)
  $stderr.puts "You have to specify at least one of --notebook or --search"
  exit(1)
end
exps = [ options.searchexp ? options.searchexp : nil,
         options.notebook ? "notebook:#{options.notebook}" : nil,
         options.tag ? "tag:#{options.tag}" : nil,
       ]
searchexp = exps.join(' ')
        
puts "Output dir: #{options.outdir}"
puts "Search expression: #{searchexp}"

# Initialize Evernote access
Evernote_utils.init

puts
puts "Reading all notes from #{searchexp}"
puts

filter = Evernote::EDAM::NoteStore::NoteFilter.new
filter.words = searchexp
filter.order = Evernote::EDAM::Type::NoteSortOrder::CREATED
filter.ascending = false

spec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new
spec.includeTitle = true
spec.includeCreated = true
spec.includeTagGuids = true
spec.includeContentLength = true

results = Evernote_utils.noteStore.findNotesMetadata(Evernote_utils.authToken,
                                                     filter,
                                                     0,
                                                     Evernote::EDAM::Limits::EDAM_USER_NOTES_MAX,
                                                     spec)

hugo = Hugo.new(options.outdir)
  
results.notes.each do |metadata|
  puts "######################################################################"
  note = Evernote_utils.getWholeNote(metadata.guid)
  hugo.output_note(metadata, note)
end
