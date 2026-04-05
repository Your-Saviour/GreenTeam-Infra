# base_hardening::ssh — harden SSH configuration

class base_hardening::ssh {
  package { 'openssh-server':
    ensure => installed,
  }

  service { 'sshd':
    ensure  => running,
    enable  => true,
    require => Package['openssh-server'],
  }

  # Drop a hardening config snippet into sshd_config.d
  # This overrides defaults without modifying the main sshd_config
  file { '/etc/ssh/sshd_config.d/99-hardening.conf':
    ensure  => file,
    content => "# Managed by Puppet — base_hardening::ssh
PermitRootLogin no
PasswordAuthentication no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
",
    require => Package['openssh-server'],
    notify  => Service['sshd'],
  }
}
