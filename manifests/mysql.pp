class anycloud::mysql inherits anycloud {
  package { [ "mysql-server", "mysql", "mysql-devel" ]:
    ensure => installed,
  }

  service { 'mysqld':
    ensure  => running,
    enable  => true,
    require => Package['mysql-server']
  }
}