module Puppet::Parser::Functions

  newfunction(:path_explode, :type => :rvalue, :doc => <<-'ENDHEREDOC') do |args|
    Given a Linux filesystem path, returns an array of all the directories
    in the path, so it can be used to emulate mkdir -p using puppet 
    file resource.

    For example:

        $test = path_explode('/opt/test/app/base')
        => ["/opt", "/opt/test", "/opt/test/app", "/opt/test/app/base"]
    ENDHEREDOC

    unless args.length == 1
      raise Puppet::ParseError, ("path_explode(): wrong number of arguments (#{args.length}; must be 1)")
    end

    path = args[0]
    arrpath = path.split('/')
    arrpath.each_with_index.map {|i, j| arrpath[0..j].join('/') }.delete_if {|i| i.empty? }
  end
end
