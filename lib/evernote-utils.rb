#
# Evernote access utilities
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-03-29 11:44:25 diego>

class Evernote_utils

  @@authToken = nil
  @@userStore = nil
  @@noteStore = nil
  @@notebooks = nil
  @@tags      = nil

  def self.authToken
    if @@authToken == nil
      if ENV['EN_AUTH_TOKEN'].nil?
        $stderr.puts("For now this script needs an Evernote developer token.")
        $stderr.puts("To get a developer token, visit")
        $stderr.puts("https://sandbox.evernote.com/api/DeveloperToken.action")
        $stderr.puts("Once you get it, store it in the EN_AUTH_TOKEN environment variable.")
        exit(1)
      end
      @@authToken = ENV['EN_AUTH_TOKEN']
    end
    return @@authToken
  end

  def self.userStore
    if @@userStore == nil
      # Initial development is performed on our sandbox server. To use the production
      # service, change "sandbox.evernote.com" to "www.evernote.com" and replace your
      # developer token above with a token from
      # https://www.evernote.com/api/DeveloperToken.action
      evernoteHost = "sandbox.evernote.com"
      userStoreUrl = "https://#{evernoteHost}/edam/user"

      userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
      userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
      @@userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)
    end
    return @@userStore
  end

  def self.checkVersion
    versionOK = self.userStore.checkVersion("enwrite",
				            Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
				            Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
    puts "Is my Evernote API version up to date?  #{versionOK}"
    puts
    unless versionOK
      puts "Please update the Evernote Ruby libraries."
      exit(1)
    end
  end

  def self.noteStore
    if @@noteStore == nil
      # Get the URL used to interact with the contents of the user's account
      # When your application authenticates using OAuth, the NoteStore URL will
      # be returned along with the auth token in the final OAuth request.
      # In that case, you don't need to make this call.
      noteStoreUrl = self.userStore.getNoteStoreUrl(self.authToken)

      noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
      noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
      @@noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
    end
    return @@noteStore
  end
  
  def self.notebooks(force=false)
    if (@@notebooks == nil) or force
      # List all of the notebooks in the user's account
      @@notebooks = self.noteStore.listNotebooks(self.authToken)
      puts "Found #{notebooks.size} notebooks:"
      defaultNotebook = notebooks.first
      notebooks.each do |notebook|
        puts "  * #{notebook.name}"
      end
    end
    return @@notebooks
  end

  def self.tags(force=false)
    if (@@tags == nil) or force
      puts "Reading all tags:"
      
      # Get list of all tags, cache it for future use
      taglist = self.noteStore.listTags(self.authToken)
      # Create a hash for easier reference
      @@tags = {}
      for t in taglist
        @@tags[t.guid] = t
        @@tags[t.name] = t
        print "#{t.name} "
      end
      puts
    end
    return @@tags
  end
  
  def self.init
    self.authToken
    self.userStore
    self.checkVersion
    self.noteStore
    
    self.notebooks
    self.tags
  end

  def self.getWholeNote(metadata)
    note = self.noteStore.getNote(self.authToken, metadata.guid, true, true, false, false)
    note.tagNames = []
    if metadata.tagGuids != nil
      tags = Evernote_utils.tags
      note.tagNames = metadata.tagGuids.map { |guid| tags[guid].name }
    end
    puts "Tags: #{note.tagNames}"
    return note
  end
  
end
