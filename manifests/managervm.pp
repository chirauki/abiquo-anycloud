class anycloud::managervm (
  $rubyver = 'ruby-2.0.0-p247',
){
  include rvm

  # ensure rvm doesn't timeout finding binary rubies
  # the umask line is the default content when installing rvm if file does not exist
  file { '/etc/rvmrc':
    content => 'umask u=rwx,g=rwx,o=rx
                export rvm_max_time_flag=20
                ',
    mode    => '0664',
  }

  rvm_system_ruby { $rubyver: 
    ensure      => present, 
    default_use => true,
    require     => File['/etc/rvmrc']
  }

  ## Install puppet in new gemset so we can use it again
  rvm_gem { 'puppet':
      name         => 'puppet',
      ruby_version => $rubyver,
      ensure       => present,
      require      => Rvm_system_ruby[$rubyver]
  }

  rvm_gem { 'bundler':
      name         => 'bundler',
      ruby_version => $rubyver,
      ensure       => present,
      require      => Rvm_system_ruby[$rubyver]
  }
}