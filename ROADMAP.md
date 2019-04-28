# Roadmap for Sympa Ansible Provisioning

## Phase one: fix security concerns

Take care of the following issues:

* [Replacing keyczar by native Ansible vault. #64](https://github.com/sympa-community/sympa-ansible/pull/64)
* [Ansible keystore is world readable #55](https://github.com/sympa-community/sympa-ansible/issues/55)

## Phase two: cleanup what is unnecessary

Replace scripts with native Ansible.

## Phase three: revamping virtual host management 

Use a list of virtual hosts per server in the inventory, similar to what the
[geerlingguy.nginx](https://github.com/geerlingguy/ansible-role-nginx) role does.

## Phase four: break out the roles

We want to have separate roles for all parts of a complete Sympa
installation:

  * database
    * mysql/mariadb
    * PostgreSQL
  * sympa
  * mailserver
    * postfix
    * smtp
  * webserver
    
## Phase five: use external roles from Ansible Galaxy

Check whether there are external roles which can replace existing internal
roles. Popular external roles are usually tested more thoroughly and have
more options for different use cases and server types.

It is useful to wrap external roles into an internal role, so we can adjust
variables etc:

```
- name: Run external MySQL role
  import_role:
    name: geerlingguy.mysql
  vars:
    mysql_packages:
      - mariadb-server
      - mariadb-client`
```
