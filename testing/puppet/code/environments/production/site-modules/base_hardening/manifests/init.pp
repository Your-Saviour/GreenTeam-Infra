# base_hardening — NTP, SSH hardening, firewall basics, fail2ban, auto security updates

class base_hardening {
  include base_hardening::ntp
  include base_hardening::ssh
  include base_hardening::firewall
  include base_hardening::fail2ban
  include base_hardening::auto_updates
}
