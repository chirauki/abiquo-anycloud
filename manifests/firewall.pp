class anycloud::firewall inherits anycloud {
  resources { "firewall":
    purge => true
  }

  Firewall {
    before  => Class['anycloud::firewall::post'],
    require => Class['anycloud::firewall::pre'],
  }

  class { ['anycloud::firewall::pre', 'anycloud::firewall::post']: }

  firewall { '100 allow http and https access':
    port   => [80, 443],
    proto  => tcp,
    action => accept,
  }->
  firewall { '100 allow ssh access':
    port   => 22,
    proto  => tcp,
    action => accept,
  }
}