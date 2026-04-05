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

  # Use sshd_config.d drop-in to avoid conflicts with duplicate directives
  # in the default sshd_config (e.g. PermitRootLogin appears in Match blocks)
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
