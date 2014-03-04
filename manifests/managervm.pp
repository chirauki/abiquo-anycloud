class anycloud::managervm (
  $rubyver = 'ruby-2.0.0-p247',
){
  include rvm

  rvm_system_ruby { $rubyver: 
    ensure      => present, 
    default_use => true,
    require     => File['/etc/rvmrc']
  }

  exec { 'Set default gemset':
    path    => "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/rvm/bin",
    command => "rvm gemset use ${rubyver}@AbiSaaS --default",
    require => Rvm_gemset["${rubyver}@AbiSaaS"]
  }

  rvm_gemset { "${rubyver}@AbiSaaS":
    ensure  => present,
    require => Rvm_system_ruby[$rubyver]
  }

  rvm_gem { "bundler":
      ruby_version => "${rubyver}",
      ensure       => "1.3.5",
      require      => Rvm_system_ruby[$rubyver]
  }

  rvm_gem { "puppet":
      ruby_version => "${rubyver}",
      ensure       => latest,
      require      => Rvm_system_ruby[$rubyver]
  }
}