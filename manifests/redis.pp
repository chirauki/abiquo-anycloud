class anycloud::redis inherits anycloud {
  include anycloud::epel

  package { "redis":
    ensure  => installed,
    require => Package['epel-release']
  }
  
  service { 'redis':
    ensure  => running,
    enable  => true,
    require => Package['redis']
  }
}