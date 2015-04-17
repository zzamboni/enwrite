require 'yaml/store'
require 'colorize'

# Message output

def verbose(msg)
  puts ("Enwrite [VERBOSE]: " + msg).blue if $enwrite_verbose
end

def error(msg)
  $stderr.puts ("Enwrite [ERROR]: " + msg).red
end

def msg(msg)
  puts ("Enwrite [INFO]: " + msg).green
end

def warn(msg)
  $stderr.puts ("Enwrite [WARN]: " + msg).light_yellow
end

# Config file storage

def config_file
  return "#{ENV['HOME']}/.enwrite.config"
end

def config_store
  return YAML::Store.new(config_file())
end

# Get a persistent config value
def config(key, defval=nil)
  store = config_store
  return store.transaction { store.fetch(key, defval) }
end

# Set a persistent config value
def setconfig(key, val)
  store = config_store
  return store.transaction { store[key] = val }
end  
