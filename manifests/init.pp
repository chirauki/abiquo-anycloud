# == Class: anycloud
#
# Main class for the Abiquo anyCloud module.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { anycloud:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2014 Your name here, unless otherwise noted.
#
class anycloud (
  $environment  = "development",
  $rubyver      = 'ruby-2.0.0-p247',
  $passengerver = '4.0.33',
  $consoleurl   = "http://localhost/ui",
  $apiurl       = "http://localhost/api",
){
  include anycloud::epel
  include anycloud::redis
  include anycloud::mysql
  include anycloud::firewall

  $deps = ["sqlite", "sqlite-devel", "crontabs", "curl", "sudo", "bzip2", "nodejs", "git"]
  package { $deps:
    ensure  => installed,
    require => Package['epel-release']
  }

  class { 'apache':
    default_mods        => false,
    default_vhost       => false,
    default_confd_files => false,
  }

  apache::mod { 'env': }
  class { 'apache::mod::dir': }
  class { 'apache::mod::rewrite': }
  
  class { 'apache::mod::proxy_html': }

  $proxy_pass = [
    { 'path' => '/abiquo/api', 'url' => $apiurl },
    { 'path' => '/abiquo/ui', 'url' => $consoleurl },
  ]

  apache::vhost { 'anycloud.example.com':
    port            => '443',
    docroot         => '/opt/rails/AbiSaaS/current/public',
    ssl             => true,
    setenv          => ["RAILS_ENV ${environment}"],
    custom_fragment => "ProxyPassReverseCookiePath /api /abiquo/api",
    proxy_pass      => $proxy_pass,
    require         => File['/opt/rails/AbiSaaS/current']
  }

  apache::vhost { 'abiquo-redir':
    port      => '80',
    docroot   => '/var/www/html',
    ssl       => false,
    rewrites  => [ { rewrite_rule => ['.* https://%{SERVER_NAME}%{REQUEST_URI} [L,R=301]'] } ],
  }

  class { 'rvm::passenger::apache': 
    version       => $passengerver, 
    ruby_version  => $rubyver,
  }

  class { 'anycloud::managervm':
    rubyver => $rubyver
  }

  # To overcome https://github.com/puppetlabs/puppetlabs-apache/pull/607
  exec { 'Change passenger module file':
    path    => "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin",
    command => "sed -i \"s/modules\\/mod_passenger.so/\\/usr\\/local\\/rvm\\/gems\\/${rubyver}\\/gems\\/passenger-${passengerver}\\/buildout\\/apache2\\/mod_passenger.so/g\" /etc/httpd/conf.d/passenger.load",
    unless  => "grep passenger-${passengerver} /etc/httpd/conf.d/passenger.load",
    require => File['passenger.load'],
    notify  => Service['httpd']
  }

  class { 'selinux': 
    mode => 'disabled'
  }

  host { 'Add hostname to /etc/hosts':
    ensure  => present,
    name    => $::hostname,
    ip      => $::ipaddress,
  }
  
  group { ['deployers', 'AbiSaaS']:
    ensure  => present,
  }

  # AbiSaaS home and home files
  file { '/home/AbiSaaS':
    ensure  => directory,
    owner   => 'AbiSaaS',
    group   => 'AbiSaaS',
    require => [ Group['AbiSaaS'], User['AbiSaaS'] ]
  }

  file { '.bashrc':
    path    => "/home/AbiSaaS/.bashrc",
    source  => "puppet:///modules/anycloud/AbiSaaS.bashrc",
    owner   => 'AbiSaaS',
    group   => 'AbiSaaS',
    require => File['/home/AbiSaaS']
  }

  file { '.bash_profile':
    path    => "/home/AbiSaaS/.bash_profile",
    source  => "puppet:///modules/anycloud/AbiSaaS.bash_profile",
    owner   => 'AbiSaaS',
    group   => 'AbiSaaS',
    require => File['/home/AbiSaaS']
  }

  user { 'AbiSaaS':
    ensure      => present,
    gid         => 'deployers',
    home        => '/home/AbiSaaS',
    managehome  => true,
    shell       => "/bin/bash",
    require     => Group['deployers', 'AbiSaaS']
  }

  ssh_authorized_key { 'Ssh key':
    ensure    => present,
    key       => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQCxwT+/WJ7h3DkUcxlJwZ+p3r87RAR7//sj/b3Z4lOcFJaZfLUxe4DBxasyUfNd7xtuMnT0hzKAoB/5odUpQeHWYcu4rc4d03872VKmU2StHdbytMu8wH+gK06nAsiq4bqTMuW+WzlNqysVLIgWWvbSKqwVZVbDvYYM7GjqmUX8VOMaI+Xsi/gegRS0FT0mwGwK3gbCFI8DTLbFlz1/UWt5D9Nvfji0QaCsQiG/GNdiqAMIDu25JP0XWlBIzA83VmXF5yVmgMjKMgrScOH2pvpZMGwGebotWCdTbwFjAmDyb8rYpXPjdIk/gm9whhCpSw/qDUORxifo8AoO/V7pXyK7',
    user      => 'AbiSaaS',
    type      => 'ssh-rsa',
    require   => User['AbiSaaS']
  }

  file { [ '/opt/rails', 
          '/opt/rails/AbiSaaS', 
          '/opt/rails/AbiSaaS/releases', 
          '/opt/rails/AbiSaaS/releases/dummy', 
          '/opt/rails/AbiSaaS/releases/dummy/public' ]:
    ensure  => directory,
    owner   => 'AbiSaaS',
    group   => 'apache',
    mode    => '0755',
    require => [ Group['deployers'], User['AbiSaaS'] ]
  }

  file { '/opt/rails/AbiSaaS/current':
    ensure  => link,
    target  => '/opt/rails/AbiSaaS/releases/dummy',
    owner   => 'AbiSaaS',
    group   => 'AbiSaaS',
    require => File['/opt/rails/AbiSaaS/releases/dummy']
  }

  file { '/etc/sudoers.d/abisaas':
    ensure  => present,
    source  => "puppet:///modules/anycloud/abisaas.sudoers",
    owner   => 'root',
    group   => 'root'
  }

  rvm::system_user { ['AbiSaaS', 'apache']:
    require => User['AbiSaaS']
  }
}
