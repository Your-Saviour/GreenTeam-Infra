# base_hardening::fail2ban — install and configure fail2ban for SSH

class base_hardening::fail2ban {
  package { 'fail2ban':
    ensure => installed,
  }

  # Local config overrides — won't be clobbered by package updates
  file { '/etc/fail2ban/jail.local':
    ensure  => file,
    content => "[DEFAULT]\nbantime = 3600\nfindtime = 600\nmaxretry = 3\n\n[sshd]\nenabled = true\nport = ssh\nfilter = sshd\nlogpath = /var/log/auth.log\n",
    require => Package['fail2ban'],
    notify  => Service['fail2ban'],
  }

  service { 'fail2ban':
    ensure  => running,
    enable  => true,
    require => Package['fail2ban'],
  }
}
