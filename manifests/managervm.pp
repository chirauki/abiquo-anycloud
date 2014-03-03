class anycloud::managervm (
  $rubyver = 'ruby-2.0.0-p247',
){
  include rvm

  rvm_system_ruby { $rubyver: 
    ensure      => present, 
    default_use => true,
    require     => File['/etc/rvmrc']
  }

  rvm_gem { 'bundler':
      name         => 'bundler',
      ruby_version => $rubyver,
      ensure       => "1.3.5",
      require      => [ Rvm_system_ruby[$rubyver], Exec['Update gems'] ]
  }
}