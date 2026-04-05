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

  # Harden sshd_config
  $ssh_settings = {
    'PermitRootLogin'        => 'no',
    'PasswordAuthentication' => 'no',
    'X11Forwarding'          => 'no',
    'MaxAuthTries'           => '3',
    'ClientAliveInterval'    => '300',
    'ClientAliveCountMax'    => '2',
    'Protocol'               => '2',
  }

  $ssh_settings.each |String $key, String $value| {
    file_line { "sshd_config_${key}":
      ensure => present,
      path   => '/etc/ssh/sshd_config',
      line   => "${key} ${value}",
      match  => "^#?\\s*${key}\\s",
      notify => Service['sshd'],
    }
  }
}
