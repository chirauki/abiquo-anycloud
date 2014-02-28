class anycloud::firewall::post {
  firewall { '200 drop all':
    proto   => 'all',
    action  => 'drop',
    before  => undef,
  }
}