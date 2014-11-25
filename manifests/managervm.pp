class anycloud::managervm (
  $rubyver          = 'ruby-2.0.0-p247',
  $bundler_gem_ver  = '1.3.5',
  $puppet_gem_ver   = '3.7.1',
){

  rvm_system_ruby { $rubyver: 
    ensure      => present, 
    default_use => true,
    require     => Exec["Set ${rubyver} as default"]
  }

  exec { "Get RVM GPG key":
    path    => "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/rvm/bin",
    command => "sudo gpg2 --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3",
    user    => "AbiSaaS",
    onlyif  => "/usr/bin/which gpg2",
    require => [ User["AbiSaaS"], File['/etc/sudoers.d/abisaas'] ]
  }->
  exec { "Install RVM":
    path    => "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/rvm/bin",
    command => "curl -sSL https://get.rvm.io | sudo bash -s stable",
    user    => "AbiSaaS",
    require => [ User["AbiSaaS"], File['/etc/sudoers.d/abisaas'] ]
  }->
  exec { "Install Ruby version ${rubyver}":
    path    => "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/rvm/bin",
    command => "rvm install ${rubyver}",
    creates => "/usr/local/rvm/gems/ruby-2.0.0-p247",
    require => Exec["Install RVM"]
  }->
  exec { "Set ${rubyver} as default":
    path    => "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/rvm/bin",
    command => "rvm use ${rubyver} --default",
    require => Exec["Install Ruby version ${rubyver}"]
  }

  rvm_gem { "bundler":
      ruby_version => "${rubyver}",
      ensure       => "1.3.5",
      require      => Exec["Set ${rubyver} as default"]
  }

  rvm_gem { "puppet":
      ruby_version => "${rubyver}",
      ensure       => "3.7.1",
      require      => Exec["Set ${rubyver} as default"]
  }
}