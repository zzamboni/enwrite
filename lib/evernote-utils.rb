#
# Evernote access utilities
#
# Diego Zamboni, March 2015

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
  SANDBOX = false

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

I can store the token for you in the config file (#{config_file}),
then enwrite will use it automatically in the future.
")
    print "Would you like me to do that for you now (Y/n)? "
    $stdout.flush
    yesno = gets.chomp
    if yesno =~ /^([yY].*|)$/
      setconfig(:evernote_auth_token, access_token.token)
      puts "Token stored."
    else
      puts "OK, I won't store the token, just use it for now.

You can also store it in the ENWRITE_AUTH_TOKEN environment variable."
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
    elsif not config(:evernote_auth_token).nil?
      return config(:evernote_auth_token)
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
      tagstr = ""
      for t in taglist
        @@tags[t.guid] = t
        @@tags[t.name] = t
        tagstr += "#{t.name} "
      end
      verbose tagstr
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

  # From http://pollen.io/2012/12/creating-a-note-in-evernote-from-ruby/
  # With changes to handle RATE_LIMIT_REACHED
  def self.translate_error(e)
    error_name = "unknown"
    case e.errorCode
    when Evernote::EDAM::Error::EDAMErrorCode::AUTH_EXPIRED
      error_name = "AUTH_EXPIRED"
    when Evernote::EDAM::Error::EDAMErrorCode::BAD_DATA_FORMAT
      error_name = "BAD_DATA_FORMAT"
    when Evernote::EDAM::Error::EDAMErrorCode::DATA_CONFLICT
      error_name = "DATA_CONFLICT"
    when Evernote::EDAM::Error::EDAMErrorCode::DATA_REQUIRED
      error_name = "DATA_REQUIRED"
    when Evernote::EDAM::Error::EDAMErrorCode::ENML_VALIDATION
      error_name = "ENML_VALIDATION"
    when Evernote::EDAM::Error::EDAMErrorCode::INTERNAL_ERROR
      error_name = "INTERNAL_ERROR"
    when Evernote::EDAM::Error::EDAMErrorCode::INVALID_AUTH
      error_name = "INVALID_AUTH"
    when Evernote::EDAM::Error::EDAMErrorCode::LIMIT_REACHED
      error_name = "LIMIT_REACHED"
    when Evernote::EDAM::Error::EDAMErrorCode::PERMISSION_DENIED
      error_name = "PERMISSION_DENIED"
    when Evernote::EDAM::Error::EDAMErrorCode::QUOTA_REACHED
      error_name = "QUOTA_REACHED"
    when Evernote::EDAM::Error::EDAMErrorCode::SHARD_UNAVAILABLE
      error_name = "SHARD_UNAVAILABLE"
    when Evernote::EDAM::Error::EDAMErrorCode::UNKNOWN
      error_name = "UNKNOWN"
    when Evernote::EDAM::Error::EDAMErrorCode::VALID_VALUES
      error_name = "VALID_VALUES"
    when Evernote::EDAM::Error::EDAMErrorCode::VALUE_MAP
      error_name = "VALUE_MAP"
    when Evernote::EDAM::Error::EDAMErrorCode::RATE_LIMIT_REACHED
      error_name = "RATE_LIMIT_REACHED"
      e.message = "Rate limit reached. Please retry in #{e.rateLimitDuration} seconds"
    end
    rv = "Error code was: #{error_name}[#{e.errorCode}] and parameter: [#{e.message}]"
  end
end
