# base_hardening::auto_updates — enable automatic security updates

class base_hardening::auto_updates {
  package { 'unattended-upgrades':
    ensure => installed,
  }

  # Enable automatic security updates
  file { '/etc/apt/apt.conf.d/20auto-upgrades':
    ensure  => file,
    content => "APT::Periodic::Update-Package-Lists \"1\";\nAPT::Periodic::Unattended-Upgrade \"1\";\n",
    require => Package['unattended-upgrades'],
  }
}
