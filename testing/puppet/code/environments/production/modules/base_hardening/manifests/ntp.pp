# base_hardening::ntp — ensure NTP is installed and running

class base_hardening::ntp {
  package { 'chrony':
    ensure => installed,
  }

  service { 'chrony':
    ensure  => running,
    enable  => true,
    require => Package['chrony'],
  }
}
