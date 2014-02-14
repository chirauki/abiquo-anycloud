class anycloud::epel inherits anycloud {
  package { 'epel-release':
    ensure    => present,
    source    => 'http://ftp.cica.es/epel/6/x86_64/epel-release-6-8.noarch.rpm',
    provider  => 'rpm'
  }
}