module Puppet::Parser::Functions

  newfunction(:hash2yaml, :type => :rvalue, :doc => <<-'ENDHEREDOC') do |args|
    Returns the YAML representation of the provided hash.

    For example:

        $test = hash2yaml($myhash)
    ENDHEREDOC

    def sort_hash(hash)
      hash.keys.each do |k|
        if hash[k].is_a?(Hash)
          hash[k] = sort_hash(hash[k])
        end
      end
      Hash[hash.sort]
    end

    unless args.length == 1
      raise Puppet::ParseError, ("hash2yaml(): wrong number of arguments (#{args.length}; must be 1)")
    end

    sorted = sort_hash(args[0])
    sorted.to_yaml

  end
end
