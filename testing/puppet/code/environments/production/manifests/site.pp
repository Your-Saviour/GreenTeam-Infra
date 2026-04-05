# site.pp — applies base hardening to all nodes

node default {
  include base_hardening
}
