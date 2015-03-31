
def verbose(msg)
  puts msg if $enwrite_verbose
end

def error(msg)
  $stderr.puts msg
end
