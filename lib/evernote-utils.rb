#
# Evernote access utilities
#
# Diego Zamboni, March 2015
# Time-stamp: <2015-03-30 17:52:54 diego>

# Load libraries required by the Evernote OAuth
require 'oauth'
require 'oauth/consumer'
 
# Load Thrift & Evernote Ruby libraries
require "evernote_oauth"

class Evernote_utils

  # Client credentials for enwrite
  OAUTH_CONSUMER_KEY = "zzamboni-2648"
  OAUTH_CONSUMER_SECRET = "05f988c37b5e8c68"
  
  # Connect to Sandbox server?
  SANDBOX = true

  # File where to store and look for the auth token
  TOKENFILE = "#{ENV['HOME']}/.enwrite-auth-token"

  # Environment variable in which to look for the token
  ENVVAR = 'ENWRITE_AUTH_TOKEN'
  
  @@authToken = nil
  @@userStore = nil
  @@noteStore = nil
  @@notebooks = nil
  @@tags      = nil
  @@forceAuth = false

  def self.interactiveGetToken
    callback_url = "http://zzamboni.org/enwrite-callback.html"
    client = EvernoteOAuth::Client.new(token: nil, consumer_key: OAUTH_CONSUMER_KEY, consumer_secret: OAUTH_CONSUMER_SECRET, sandbox: SANDBOX)
    request_token = client.request_token(:oauth_callback => callback_url)
    authorize_url = request_token.authorize_url

    puts("Welcome to enwrite's Evernote authentication.

Please open the following URL:
#{authorize_url}

Once you authenticate you will be redirected to
a page in the zzamboni.org domain that will show you an authentication verifier
token. Please enter that token now.")
    print("> ")
    $stdout.flush
    oauth_verifier = gets.chomp

    access_token = request_token.get_access_token(:oauth_verifier => oauth_verifier)

    puts("Thank you! Your access token is the following string:
#{access_token.token}

I can store the token for you in #{TOKENFILE},
then enwrite will use it automatically in the future.
")
    print "Would you like me to do that for you now (Y/n)? "
    $stdout.flush
    yesno = gets.chomp
    if yesno =~ /^[yY]/
      File.open(TOKENFILE, "w") do |f|
        f.puts(access_token.token)
      end
      puts "Token stored."
    else
      puts "OK, I won't store the token, just use it for now.

You can also store it in the ENWRITE_AUTH_TOKEN environment variable, or store
it yourself later in #{TOKENFILE} if you want to keep it around."
    end
    # Cancel force mode after we've gotten the token
    @@forceAuth = false
    
    return access_token.token
  end
  
  def self.getToken
    if @@forceAuth
      return self.interactiveGetToken
    elsif not ENV[ENVVAR].nil?
      return ENV[ENVVAR]
    elsif File.exists?(TOKENFILE)
        File.open(TOKENFILE, "r") do |f|
          token = f.gets.chomp
          return token
          end
    else
      return self.interactiveGetToken
    end
  end
  
  def self.authToken
    if @@authToken == nil || @@forceAuth
      @@authToken = self.getToken
    end
    return @@authToken
  end

  def self.userStore
    if @@userStore == nil
      # Initial development is performed on our sandbox server. To use the production
      # service, change "sandbox.evernote.com" to "www.evernote.com" and replace your
      # developer token above with a token from
      # https://www.evernote.com/api/DeveloperToken.action
      evernoteHost = SANDBOX ? "sandbox.evernote.com" : "www.evernote.com"
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
    verbose "Is my Evernote API version up to date?  #{versionOK}"
    unless versionOK
      error "Please update the Evernote Ruby libraries - they are not up to date."
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
      verbose "Found #{notebooks.size} notebooks:"
      defaultNotebook = notebooks.first
      notebooks.each do |notebook|
        verbose "  * #{notebook.name}"
      end
    end
    return @@notebooks
  end

  def self.tags(force=false)
    if (@@tags == nil) or force
      verbose "Reading all tags:"
      
      # Get list of all tags, cache it for future use
      taglist = self.noteStore.listTags(self.authToken)
      # Create a hash for easier reference
      @@tags = {}
      for t in taglist
        @@tags[t.guid] = t
        @@tags[t.name] = t
        print "#{t.name} " if $enwrite_verbose
      end
      verbose("")
    end
    return @@tags
  end
  
  def self.init(force=false, token=nil)
    @@forceAuth = force
    if not token.nil?
      @@forceAuth = false
      @@authToken = token
    end
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
    verbose "Tags: #{note.tagNames}"
    return note
  end
  
end
