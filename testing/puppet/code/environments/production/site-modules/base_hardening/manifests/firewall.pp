# base_hardening::firewall — enable UFW with basic rules

class base_hardening::firewall {
  package { 'ufw':
    ensure => installed,
  }

  # Allow SSH before enabling
  exec { 'ufw-allow-ssh':
    command => '/usr/sbin/ufw allow 22/tcp',
    unless  => '/usr/sbin/ufw status | /usr/bin/grep -q "22/tcp.*ALLOW"',
    require => Package['ufw'],
  }

  # Allow Puppet agent traffic
  exec { 'ufw-allow-puppet':
    command => '/usr/sbin/ufw allow out 8140/tcp',
    unless  => '/usr/sbin/ufw status | /usr/bin/grep -q "8140/tcp.*ALLOW"',
    require => Package['ufw'],
  }

  # Enable UFW (--force skips interactive prompt)
  exec { 'ufw-enable':
    command => '/usr/sbin/ufw --force enable',
    unless  => '/usr/sbin/ufw status | /usr/bin/grep -q "Status: active"',
    require => [Exec['ufw-allow-ssh'], Exec['ufw-allow-puppet']],
  }
}
