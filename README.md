# Sympa deployment with Ansible

[Sympa](https://www.sympa.org/) is an open source mailing list software

[Ansible](http://docs.ansible.com/) is an IT automation tool. It can configure systems, deploy software.

# [Quickstart: Creating a development VM](id:quickstart)

First install the tools on your local machine:

* Install [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org).
Virtualbox will run the development VM and Vagrant is used to create, configure and manage the development VM instance.
**Vagrant 2 and later is required** (there is problems with previous versions).
* Install [Ansible](http://www.ansible.com). There are several ways to install Ansible.
They are described in the [Ansible installation guide](http://docs.ansible.com/ansible/intro_installation.html).
**Ansible 2.5 is required** for the _include-role_ feature to be used.

Clone or download this repository to your local machine:

    $ git clone https://github.com/sympa-community/sympa-ansible.git

Next change into the "sympa-ansible" directory and start the development VM: 

    $ vagrant up

This prepares a VM that is ready to be managed by Ansible. It will call a
simple Ansible playbook to make some changes to the VM and create an
inventory in `environments/local`.

A starting point for a playbook is provided. Run the playbook "site.yml": 

    $ ansible-playbook site.yml -i environments/local/inventory

You can login to the VM using `$ vagrant ssh`

> By default, Vagrant shares your project directory (remember, that is the one with the Vagrantfile) to the /vagrant directory in your guest machine.

You should add an entry in your host _/etc/hosts_ file for the VM's IP address

    192.168.66.67 lists.example.com robot1.example.com robot2.example.com

You can now connect to your Sympa server web interface [https://lists.example.com/sympa](https://lists.example.com/sympa).

# Fresh environment layout

Once you have created the environment, here is the layout of the environment directory:

  - group_vars/
  - private/
  - tasks/
  - templates/
  - vault-password

## vault-password file

This file contains the vault secret (https://docs.ansible.com/ansible/latest/user_guide/vault.html). Please make
sure that the permissions stay prohibitive (write and read only for the
current user).

## group_vars directory

This directory contains the variables global to all domains.

It contains three files:

  - all.yml
  - postfix.yml
  - sympa.yml

### all.yml file

This file contains parameters global to all servers and domains.
Especially, it contains variables that will be visible to all roles.
For example, it contains the definition of
the db root credentials (as they will be common to Sympa and any other application). It also defines the web and mail
default domains, as well as the global admins.
Anything not specifically related to either mail or sympa should go there.

Here is the default file content:

```
managed_file_dir: /opt/ansible/managed_files

timezone: Europe/Amsterdam

ansible_remote_user: root

install_prefix: /usr/local

db:
  root_password: "{{ lookup('file',inventory_dir+'/private/password/db_root_password') }}"
  root_user: root

common:
  ip: "*"
  port: 443
  ssl:
    enabled: yes
    selfsignedcertificate: yes
  web:
    domain: lists.example.com
    admin: support@renater.fr
  mail:
    domain: lists.example.com
  admins:
    - david@example.com
    - etienne@example.com
    - olivier@example.com    
  check_smtp:
    smtp_out: localhost
    address: check-smtp-service-ping
    auth_secret: foobar
    max_delay: 300
      
```

### postfix.yml

This file contains the global parameters for postfix.

All data must be located under the namespace `mail`.

Here is the default file content: 

```
mail:
  force_smtp_route: 1
  outgoing_server: '192.168.66.66'
  incoming_smtp: '192.168.66.66'
  alias_files:
    basic: /etc/aliases
```

### sympa.yml

This file contain Sympa-only parameters.

All parameters are under the `sympa` namespace. 

Here is the default file content:

```
sympa:
  db:
    app_user: sympa
    app_password: "{{ lookup('file',inventory_dir+'/private/password/sympa_db_app_password') }}"
    readonly_user: sympareadonly
    readonly_password: "{{ lookup('file',inventory_dir+'/private/password/sympa_db_readonly_password') }}"
  lists_path: /var/lib/sympa/list_data
  arc_path: /var/lib/sympa/archives
```



### vhosts/ directory

This directory contains one file per virtual host. Any parameter can be redefined in these files,
Though it is pointless if the parameter is not virtual host-related.

by default, the environment generation script creates four domain descriptions:

  - lists.example.com.yml
  - robot1.example.com.yml
  - robot2.example.com.yml
  - robot3.example.com.yml

Example of one such file:

```
robot1.example.com:
  common:
    web:
      domain: robot1.example.com
    mail:
      domain: robot1.example.com
    admins:
      - olivier@example.com
      - etienne@example.com
      - david@example.com
  sympa:
    config:
      title: My lovely service
      create_list: listmaster
      color_6: '#FF0000'
    server: local-sympa
```

You can see that, in this file, we redefine global parameters (web and mail domain), i.e. parameters that
would be used by applications others than Sympa (Dokuwiki for example).
We also set Sympa specific parameters. Note that anything under `sympa.config` namespace will be used to generate
the robot.conf file for this domain.

A remark regarding `sympa.server`: it defines on which server this domain's Sympa will be run.
That way, you can define several Sympa servers in your inventory, and pick for each domain which one to use.

## tasks directory

This directory contains files for tasks to be executed at the end of their respective roles:

  - sympa.yml is executed at the end of the sympa role
  - apache.yml is executed at the end ot the apache role
  - common.yml is executed at the en of the common role.

Currently there are no tasks in `sympa.yml`and `apache.yml`.

Why only these three roles? Because we never had to execute other environment-specific tasks for the other roles (such as postfix).
But if you want it, just add the following  line at the end of the main.yml task of the corresponding role:

```
- include: "{{ inventory_dir }}/tasks/custom-role.yml"
```

# Available configuration parameters.

Below is the whole set of parameters used in the different files, either role defaults, or group_vars, or virtual hosts files, in that order of precedence:

If you define the same parameter in deifferent locations, it will follow the normal order of precedence in Ansible:

  1- first in group_vars,
  2- second in role defaults.

We added another level with the vhosts configuration files. If you define a parameter in the vhosts file, it will take precedence over anything else.
So the precedence is actually:

  1- first in vhosts files
  2- second in group_vars,
  3- third in role defaults.

In the `ansible.cfg` file, we setup the following parameter: `hash_behaviour=merge`.
This will trigger automatic merge of hashes. That way, you can specify in the environment only the part of hashes that are
specific to your setup. The rest of the hash keys will default to whatever can be found in the `defaults/main.yml` of the current role.

Here is the list of the parameters used in the playbook, presented as YAML data:

## global parameters

 - `install_prefix`: the root where applications should be installed. Useful if you're combining this playbook with others to install other appplications than Sympa.
 - `db.root_user`: the username of the database global root user.
 - `db.root_password`: the password of the database global root user.
 

## Sympa namespace

### unix_*

`sympa.unix_user` and `sympa.unix_group` define respectively the user and group under which the Sympa processes are executed.

### installation parameters

A set of parameters define how Sympa will be installed.

  - `sympa.install_from_repository` : if set to 1, Sympa will be installed from a checkout of a Git repository. Otherwise, a tar.gz is downloaded.
  - `sympa.install_dir_name`: the name of the directory where Sympa will be installed. It is a sub_directory of the `install_prefix` global parameter.

#### install from repository

You need to set the following parameters:

  - `sympa.install_from_repository`: value 1
  - `sympa.version`: the version of Sympa, from 6.1.17 to the latest unstable. Only used to find the patches.
  - `sympa.repository`: the URL of the git repository, to be used for the `git clone` operation.
  - `sympa.repository_version`: either `HEAD` or a commit hash.
  - `sympa.apply_patches`: if set to 1, any patch located in roles/sympa/patches/`version` will be applied to the extracted sources before the install process.

#### install from archive

You need to set the following parameters:
  
  - `sympa.install_from_repository`: value 0
  - `sympa.version`: the version of Sympa, from 6.1.17 to the latest unstable.
  - `sympa.apply_patches`: if set to 1, any patch located in roles/sympa/patches/`version` will be applied to the extracted sources before the install process.
  - `sympa.source`: the extracted archive must have the URL: `source`/sympa-`version`.tar.gz

### mail setup

for now, only Postfix is supported.
The mail setup is the same as the one proposed by the
[Sympa documentation for multiple domains support](https://sympa-community.github.io/manual/install/configure-mail-server-postfix.html#virtual-domain-setting).

  - `sympa.alias_directory`: location of the file where list alias file will be stored
  - `sympa.alias_file`: name of the alias file

### database setup

  - `sympa.db.type`: ony two values: `mysql` or `Pg`. Defines which RDBMS to use as Sympa database backend.
  - `sympa.db.app_user`: username used by Sympa for accessing its own database.
  - `sympa.db.app_password`: password used by Sympa for accessing its own database.
  - `sympa.db.readonly_user`: a user with readonly privleges to Sympa database. Can be useful.
  - `sympa.db.readonly_password`: a password for the user with readonly privleges to Sympa database.

### Sympa configuration

All parameters can't be defined in the playbook. Only the few below. Don't hesitate to change the `roles/sympa/templates/sympa.conf.j2` to add more.

  - `sympa.config.color_*`: the colors to be used for Sympa web interface.
  - `sympa.config.language`: the default server language.
  - `sympa.config.log_level`: the log level (0..4)

### Sympa paths

  - `lists_path`: full path to the directory containing the lists config.
  - `arc_path`: full path to the directory where the lists archives will be stored.


### Sympa web

The SOAP server is disabled by default. To turn it on, set
`sympa.soap.enabled` to true.

## Common namespace

### Web configuration

For now, only Apache is configured.

  - `common.ip`: ("*" by default) IP for apache vhost configuration
  - `common.port`: SSL port for Apache
  - `common.ssl.enabled`: Set to 1 to enable ssl configuration
  - `common.ssl.selfsignedcertificate`: Set to 1 if the certificate is self-signed: it implies a configuration change.
  - `common.web.domain`: web domain
  - `common.web.admin`: web admin email address

### Mail configuration

  - `common.mail.domain`: mail domain (overriden by vhosts configuration)
  - `common.mail.force_smtp_route`: if set to 1, any outgoing SMTP session will be made towards `common.mail.outgoing_server` without DNS resolution.
  - `common.mail.incoming_smtp`: the IP from which incoming mail should come to the server. Remove variable to accept any incoming server.
  - `common.mail.outgoing_server`: See `common.mail.force_smtp_route`.

### Global common parameters

  - `common.admins`: the default admins for all applictions, including Sympa. Overriden by vhosts configuration.

## Example file 

```
sympa:
  unix_user: sympa
  unix_group: sympa
  repository: https://github.com/sympa-community/git
  repository_version: HEAD
  install_from_repository: 0
  source: https://github.com/sympa-community/sympa/releases/download/
  version: 6.2.40
  install_dir_name: sympa
  apply_patches: 1
  mail:
    alias_directory: /etc/mail
    alias_file: sympa_transport
  db:
    type: mysql
    app_user: sympa
    app_password: "{{ lookup('file',inventory_dir+'/private/password/sympa_db_app_password') }}"
    readonly_user: sympareadonly
    readonly_password: "{{ lookup('file',inventory_dir+'/private/password/sympa_db_readonly_password') }}"
  config:
    color_0: '#F7F7F7'
    color_1: '#222222'
    color_2: '#004B94'
    color_3: '#5E5E5E'
    color_4: '#4c4c4c'
    color_5: '#0090E9'
    color_6: '#005ab2'
    color_7: '#fff'
    color_8: '#f2f6f9'
    color_9: '#bfd2e1'
    color_10: '#983222'
    color_11: '#66aaff'
    color_12: '#FFE7E7'
    color_13: '#f48A7b'
    color_14: '#ff9'
    color_15: '#fe57a1'
    language: 'en_US'
  lists_path: /var/lib/sympa/list_data
  arc_path: /var/lib/sympa/archives
install_prefix: /usr/local
db:
  root_password: "{{ lookup('file',inventory_dir+'/private/password/db_root_password') }}"
  root_user: root
common:
  ip: "*"
  port: 443
  ssl:
    enabled: yes
    selfsignedcertificate: yes
  web:
    domain: lists.example.com
    admin: support@renater.fr
  mail:
    domain: 'lists.example.com'
    force_smtp_route: 0
    incoming_smtp: '192.168.66.0'
    outgoing_server: '192.168.66.0'
  admins:
    - david@example.com
    - etienne@example.com
    - olivier@example.com    

```

# Defining Sympa server setup 

All configuration must be done in your environment.
There are three ways to customize your installation:

  - globally for all domains, through the files in group_vars/ directory
  - specifically for one domain through the domain files in the private/vhosts/ directory.
  - you can add environment-specific tasks in the tasks/ directory.
