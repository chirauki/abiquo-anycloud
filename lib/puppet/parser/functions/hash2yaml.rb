module Puppet::Parser::Functions

  newfunction(:hash2yaml, :type => :rvalue, :doc => <<-'ENDHEREDOC') do |args|
    Returns the YAML representation of the provided hash.

    For example:

        $test = hash2yaml($myhash)
    ENDHEREDOC

    unless args.length == 1
      raise Puppet::ParseError, ("hash2yaml(): wrong number of arguments (#{args.length}; must be 1)")
    end

    args[0].to_yaml

  end

end