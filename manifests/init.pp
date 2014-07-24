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
  $consolessl   = true,
  $consolehost  = 'localhost:443',
  $apihost      = 'localhost:8011',
  $confighash   = {
    "development" => {
      "abiquo" => {
        "consoleurl" => "http://192.168.2.211/ui",
        "apiurl" => "http://192.168.2.211/api",
        "apiuser" => "admin",
        "apipass" => "xabiquo",
        "user_role_id" => 4,
        "invited_role_id" => 2,
        "datacenter_id" => 2,
        "database_host" => "192.168.2.211",
        "database_user" => "AbiSaaS",
        "database_pass" => "pass"
      },
      "resque_redis_url" => "redis://localhost:6379",
      "google_analytics" => "UA-NOTSET",
      "max_allowed_logins" => 3,
      "logins_per_tweet" => 10,
      "jasper_server" => "http://dajasper:8080/jasperserver/rest_v2",
      "workflow_default" => "ACCEPT",
      "tweet_links" => [ "http://goo.gl/3hn6Yk", "http://bit.ly/NbaZUP", "http://tinyurl.com/ptwwmr5", "http://ow.ly/tNdZD" ]
    }
  },
  $dbhash       = {
    "development" => {
      "adapter" => "sqlite3",
      "database" => "db/development.sqlite3",
      "pool" => 5,
      "timeout" => 5000
    }
  },
  $apikeyshash  = {
    "development" => {
      "twitter" => {
        "api_key" => "notset",
        "api_secret" => "notset"
      },
      "linkedin" => {
        "api_key" => "notset",
        "api_secret" => "notset"
      },
      "mixpanel" => {
         "api_key" => "notset",
         "api_secret" => "notset",
         "token" => "notset"
      }
    }
  }
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

  class { 'anycloud::managervm':
    rubyver => $rubyver,
  }

  file { '/etc/pki/anycloud':
    ensure => directory
  }

  openssl::certificate::x509 { $::fqdn:
    ensure       => present,
    country      => 'ES',
    organization => 'Abiquo.com',
    commonname   => $::fqdn,
    state        => 'Barcelona',
    locality     => 'Barcelona',
    unit         => 'anyCloud',
    email        => 'support@abiquo.com',
    days         => 3650,
    base_dir     => '/etc/pki/anycloud',
    owner        => 'root',
    group        => 'root',
    force        => false,
    require      => File['/etc/pki/anycloud']
  }

  class { 'nginx':
    confd_purge    => true,
    vhost_purge   => true,
    proxy_set_header  => [
      'Host $host',
      'X-Real-IP $remote_addr',
      'X-Forwarded-Ssl on',
      'X-Forwarded-For $proxy_add_x_forwarded_for',
    ]
  }

  # Proxy upstreams
  nginx::resource::upstream { 'anycloud.puma':
    members => [
      'unix:///tmp/anycloud.sock'
    ]
  }

  nginx::resource::upstream { 'api':
    members => [
      $apihost
    ]
  }

  nginx::resource::upstream { 'ui':
    members => [
      $consolehost
    ]
  } 

  # HTTP vHost, redir to SSL
  nginx::resource::vhost { 'anycloud.plain':
    ensure            => present,
    server_name       => [$::fqdn],
    www_root          => '/var/www/html',
    vhost_cfg_append  => {
      'rewrite' => '^ https://$server_name$request_uri? permanent'
    }
  }

  # SSL vHost
  nginx::resource::vhost { 'anycloud.ssl':
    ensure               => present,
    www_root             => '/opt/rails/AbiSaaS/current/public',
    use_default_location => false,
    server_name          => [$::fqdn],
    listen_port          => 443,
    ssl                  => true,
    ssl_cert             => "/etc/pki/anycloud/${::fqdn}.crt",
    ssl_key              => "/etc/pki/anycloud/${::fqdn}.key",
    ssl_port             => 443,
    vhost_cfg_prepend     => {
      'set' => '$redir 0',
    },
    access_log           => '/var/log/nginx/anycloud_ssl_access.log',
    error_log            => '/var/log/nginx/anycloud_ssl_error.log',
  }

  nginx::resource::location { "root":
    ensure          => present,
    ssl             => true,
    ssl_only        => true,
    vhost           => "anycloud.ssl",
    location        => '/',
    proxy           => 'http://anycloud.puma',
  }

  nginx::resource::location { "api":
    ensure          => present,
    ssl             => true,
    ssl_only        => true,
    vhost           => "anycloud.ssl",
    location        => '/api',
    proxy           => 'http://api',
  }

  nginx::resource::location { "ui":
    ensure          => present,
    ssl             => true,
    ssl_only        => true,
    vhost           => "anycloud.ssl",
    location        => '/ui',
    proxy           => $consolessl ? {
      true  => 'https://ui/ui/',
      false => 'http://ui/ui/'
    }
  } 

  nginx::resource::location { "assets":
    ensure          => present,
    ssl             => true,
    ssl_only        => true,
    vhost           => "anycloud.ssl",
    location        => '~* ^/assets/',
    location_custom_cfg => {
      expires     => '1y',
      add_header  => 'Cache-Control public'
    }
  }

  nginx::resource::location { "javascripts":
    ensure          => present,
    ssl             => true,
    ssl_only        => true,
    vhost           => "anycloud.ssl",
    location        => '~* ^/javascripts/',
    location_custom_cfg => {
      expires     => '1y',
      add_header  => 'Cache-Control public'
    }
  }

  nginx::resource::location { "working":
    ensure          => present,
    ssl             => true,
    ssl_only        => true,
    www_root        => '/opt/rails/AbiSaaS/current/public',
    vhost           => "anycloud.ssl",
    location        => '/working'
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
          '/opt/rails/AbiSaaS/releases/dummy/public',
          '/opt/rails/AbiSaaS/shared/config',
          '/opt/rails/AbiSaaS/shared/config/environments'
          '/opt/rails/AbiSaaS/shared/config/initializers' ]:
    ensure  => directory,
    owner   => 'AbiSaaS',
    group   => 'deployers',
    mode    => '0755',
    require => [ Group['deployers'], User['AbiSaaS'] ]
  }

  # Base config files
  file { '/opt/rails/AbiSaaS/shared/config/config.yml':
    ensure  => present,
    content => hash2yaml($confighash)
    mode    => '0755',
    owner   => 'AbiSaaS',
    group   => 'AbiSaaS',
    require => File['/opt/rails/AbiSaaS/shared/config']
  }

  file { '/opt/rails/AbiSaaS/shared/config/database.yml':
    ensure  => present,
    content => hash2yaml($dbhash)
    mode    => '0755',
    owner   => 'AbiSaaS',
    group   => 'AbiSaaS',
    require => File['/opt/rails/AbiSaaS/shared/config']
  }

  file { '/opt/rails/AbiSaaS/shared/config/api_keys.yml':
    ensure  => present,
    content => hash2yaml($apikeyshash)
    mode    => '0755',
    owner   => 'AbiSaaS',
    group   => 'AbiSaaS',
    require => File['/opt/rails/AbiSaaS/shared/config']
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

  rvm::system_user { 'AbiSaaS': ; 'apache': }
}
