# Sympa deployment with Ansible

[Sympa](https://www.sympa.org/) is an open source mailing list software

[Ansible](http://docs.ansible.com/) is an IT automation tool. It can configure systems, deploy software.

This project is based on [Ansible-tools](https://github.com/pmeulen/ansible-tools), an example of Ansible Playbooks organization focusing on deployment for multiple environments,
 articulation with [Vagrant](https://www.vagrantup.com/docs/), [keyczar](https://github.com/google/keyczar) based encryption.
 Ansible-tools demonstrates a way to use Ansible to effectively and securely manage multiple environments ranging from development to production using the same playbook.

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

This prepares a VM that is ready to be managed by Ansible. It will call a simple Ansible playbook to make some changes to the VM.

Create the new environment for the VM:

    $ ./scripts/create_new_environment.sh environments/local

Provision the environment:

    $ vagrant provision

And link the inventory to your local directory:

    $ ln -s ../../.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory environments/local/inventory

Run `$ vagrant provision` to rerun just the provisioning step and update the inventory.

A starting point for a playbook is provided. Run the playbook "site.yml": 

    $ ansible-playbook site.yml -i environments/local/inventory

You can login to the VM using `$ vagrant ssh`

> By default, Vagrant shares your project directory (remember, that is the one with the Vagrantfile) to the /vagrant directory in your guest machine.

You should add an entry in your host _/etc/hosts_ file for the VM's IP address

    192.168.66.67 lists.example.com robot1.example.com robot2.example.com

You can now connect to your Sympa server web interface [https://lists.example.com/sympa](https://lists.example.com/sympa).

# Fresh environment layout

Once you have created the environment, here is the layout of the environment directory:

  - ansible-keystore/
  - group_vars/
  - private/
  - tasks/
  - templates/

## ansible-keystore directory

This directory contains the secret used by keyczar to encrypt the secrets.

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
vault_keydir: "{{ inventory_dir }}/ansible-keystore"

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
    certificate: "{{ lookup('file',inventory_dir+'/private/ssl_cert/webserver.crt') }}"
    selfsignedcertificate: yes
    key: "{{ lookup('file',inventory_dir+'/private/ssl_cert/webserver.key') }}"
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

## private directory

This directory contains data that must be saved separately for each environment, such as encrypted secrets and domain descriptions.

After the environment generation, it contains the following directories:

  - ca/
  - password/
  - ssl_cert/
  - vhosts/

### ca/ directory

a pseudo certificate authority used to generate self_signed certificates. During development,
you can chose to trust this authority to prevent browser warnings.
Note that it sould also be used to create lists email adresses certificates.

### password/ directory

This directory contains the encrypted versions of the passwords, such as db passwords.
One file per password.

### ssl_cert/ directory

This directory contains the server certificates.
Note that, for now, the playbook is quite dumb and reuses only one single certificates for all servers and virtual hosts...

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

 - `install_prefix`: the root where applications should be installed. Usefull if you're combining this playbook with others to install other appplications than Sympa.
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
  - `sympa.db.readonly_user`: a user with readonly privleges to Sympa database. Can be usefull.
  - `sympa.db.readonly_password`: a password for the user with readonly privleges to Sympa database.

### Sympa configuration

All parameters can't be defined in the playbook. Only the few below. Don't hesitate to change the `roles/sympa/templates/sympa.conf.j2` to add more.

  - `sympa.config.color_*`: the colors to be used for Sympa web interface.
  - `sympa.config.language`: the default server language.

### Sympa patchs

  - `lists_path`: full path to the directory containing the lists config.
  - `arc_path`: full path to the directory where the lists archives will be stored.


## Common namespace

### Web configuration

For now, only Apache is configured.

  - `common.ip`: ("*" by default) IP for apache vhost configuration
  - `common.port`: SSL port for Apache
  - `common.ssl.enabled`: Set to 1 to enable ssl configuration
  - `common.ssl.certificate`: Patch to the vhost certificate to install; Overriden by vhosts configuration.
  - `common.ssl.selfsignedcertificate`: Set to 1 if the certificate is self-signed: it implies a configuration change.
  - `common.ssl.key`: Private key for the certificate
  - `common.web.domain`: web domain
  - `common.web.admin`: web admin email address

### Mail configuration

  - `common.mail.domain`: mail domain (overriden by vhosts configuration)
  - `common.mail.force_smtp_route`: if set to 1, any outgoing SMTP session will be made towards `common.mail.outgoing_server` without DNS resolution.
  - `common.mail.incoming_smtp`: the IP from which incoming mail should come to the server. Leave blak if you accept any incoming server.
  - `common.mail.outgoing_server`: See `common.mail.force_smtp_route`.
  - `common.mail.enable_check_smtp`: Optional activation of a program sending mails to check whether mails arrive or not.

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
    certificate: "{{ lookup('file',inventory_dir+'/private/ssl_cert/webserver.crt') }}"
    selfsignedcertificate: yes
    key: "{{ lookup('file',inventory_dir+'/private/ssl_cert/webserver.key') }}"
  web:
    domain: lists.example.com
    admin: support@renater.fr
  mail:
    domain: 'lists.example.com'
    force_smtp_route: 0
    incoming_smtp: '192.168.66.0'
    outgoing_server: '192.168.66.0'
    enable_check_smtp: 0
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

# Ansible-tools documentation

## Organisation

The _environments_ directory contains configuration elements specific to each target environment (local VM, dev, staging, production).
This separation is what allows the configuration that is environment specific to be managed separately from the Ansible playbook(s) and roles.
Environment specific configuration are things like Hostnames, IP addresses, Firewall rules, Email addresses, Passwords, private keys, certificates etc.

The other top level directories and files are:

- The _environments_ directory containing the template for a new environments
- The _scripts_ directory containing the various scripts used to create a new environment and manage secrets and work with
  the Vault
- A _Vagrantfile_ for creating a VM using Vagrant
- _ansible.cfg_ (optional) makes playbooks run faster by enabling SSH pipelining, 
- _provision-vagrant-vm.yml_ playbook used by the Vagrant provisioning step only.

## Creating a new environment
To get started you need an environment. Ansible-tools does not ship with a ready made environment, instead it ships with the tools
to create new environments. In the environments directory of Ansible-tools you will find two directories:

- [template](#templatedir) - This is the starting point of all new environments
- [local](#localdir) - some configuration that matches the included Vagrant file.

### [About the environments/template directory](id:templatedir)

The environments/template directory contains the starting point of a new environment. It is only used during the
creation of a new environment. That means that when you start extending your playbooks, and find that you need to add
variables to a environment, you should also add these variable to the template. It is thus up to you to make sure that
the template is kept up to date as the playbooks evolve over time. Besides a tool for bootstrapping a new environment, 
think of the template as an excellent place to document the use of all variables that go into the environments.
 
The template directory contains one extra file: "environment.conf". This file contains a specification for the 
passwords and certificates to create when a new environment is created. This file is read by the _create_new_environment.sh_
script that creates a new environment.

### [About the environments/local directory](id:localdir)
The "environments/local" does not yet contain a complete environment, it contains just some configuration to work with the Vagrant 
VM. It contains:

* A symlink to the inventory file that was generated by Vagrant
* The static IP address for the VM that was configured in Vagrant

### Creating the environment
The "create_new_environment.sh" script is used to create a new environment based on the template stored in
"environments/template". The script reads the "environment.conf" file from the template. This file contains a 
specification for the passwords and certificates to create for the new environment.

To create a new environment call "create_new_environment.sh" and provide the path to the directory where to create
the new environment. The [environments/local](#localdir) used in the example below already contains an inventory and host_vars files 
that are suitable for use with Vagrant VM. Create the environment using: 

`$ ./scripts/create_new_environment.sh environments/local`

This creates a new environment in the "environments/local" directory. When the specified directory does not exists, 
the directory is created. The script will not overwrite any existing files or directories in the specified environment 
directory. Note that you can create an environment directory anywhere, it does not have to be in the same directory tree
as the playbooks and roles.

The "create_new_environment.sh" script:

- Copies the "group_vars", "handlers", "tasks" and "template" directories from the template
- Generates passwords, certificates, a keyczar key and root CA as specified in the "environment.conf in the template.
 
Because it does not overwrite existing files, you can rerun the script to generate a password or certificate when the
"environment.conf" is updated.

### Running an Ansible playbook
When you run "ansible-playbook" you need to provide it with the location of the "inventory" file in the environment. You
do this by specifying its location using the "-i" or "--inventory" in "ansible-playbook" command. E.g.

`$ ansible-playbook site.yml -i environments/local/inventory`

If you omit the inventory, Ansible will try to use an the inventory file from one of its default locations 
(/etc/ansible/hosts or ./inventory), which is probably not what you want.
 
## Working with environments from a Playbook
Ansible tools comes with a working example playbook _site.yml_. This playbook applies the _common_ role to a server. 
This common role demonstrates two environment techniques:

- Getting file [templates](#environment_templates) from an environment
- Including [tasks](#environment_files) defined in an environment

Both techniques use the Ansible _inventory_dir_ variable to refer to files from the environment, instead of using files
from the role directory. This is a useful technique for dealing with differences between environments. The goal remains
to put as little as possible in the environment, and to keep most of the functionality in the playbooks and roles.

The example role, is just that, en example. It is not used from the playbook but contains a selection of common Ansible
patterns.

### [Using a template from an environment](id:environment_templates)
Look at [roles/common/tasks/main.yml](https://github.com/pmeulen/ansible-tools/blob/master/roles/common/tasks/main.yml). 

First the standard way of using of a template defined in the role. This tasks uses the
template file from _roles/common/templates/hostname.j2_:

    - name: Set /etc/hostname to {{ inventory_hostname }}
      template: src='hostname.j2' dest='/etc/hostname'

Next an example from the same file that uses a template from the environment instead of from the role: 

    - name: Put iptables configuration
      template: src={{ inventory_dir }}/templates/common/{{item}}.j2 dest=/etc/iptables/{{ item }}
      with_items:
        - rules.v4
        - rules.v6
      notify:
      - restart iptables-persistent

Note that we use _inventory_dir_ to reference the template. The adopted convention is to store templates under 
_templates/\<role name\>/_ in de environment.

### [Including tasks defined in an environment](id:environment_tasks)
At the end of _roles/common/tasks/main.yml_ tasks from the environment are included: 

    - include: "{{ inventory_dir }}/tasks/common.yml"

Because tasks might need handlers, _roles/common/handlers/main.yml_ includes them from the environment: 

    - include: "{{ inventory_dir }}/handlers/common.yml"

Note the convention used for storing the included tasks and handlers in the environment:

- tasks/\<role name\>.yml
- handlers/\<role name\>.yml

### About the group_vars directory
You might expect there to be a top level _group_vars_ directory next to your _role_ directory. There is none, and when you
add it, you will find that it is not used. This is because _group_vars_ (and _host_vars_) directories are resolved
relative to the _inventory_ directory.

_groups_vars_ go in the environments. This means that when you add a variable, you will have to add it to **all**
environments. This is where the template environment comes in.

### The template environment
The template environment is the prototype of all new environments. During development of your playbooks and roles you
should add the variables, jinja2 templates, files, tasks and handlers that required by your roles and playbooks to the
template environment. 

#### Adding a new variable
When you add a variable in the _groups_vars_ directory of an environment, you should add it to the _groups_vars_
in the _environments/template_ directory as well. This way the template serves as a place to document the use of the
variable for all environments.

> Add all variables that are used to the template environment and document them there

But what value to give to the new variable? Give it a value that works well (i.e. without requiring to be changed) with
the development VM. This allows you to verify that the template is still up to date: create a new vm using the template.
This test can be automated.

> Make the template environment testable: Set the group_var variables in the template to values that immediately work in 
> the vm

Variables used in a role that do not typically change between environments should not be stored in the environment. These can 
be stored in the _vars_ directory of the role in the playbook.

### [Using the generated secrets in your playbooks](id:using_secrets)

The encrypted secrets, password and certificates to be created by the _create_new_environment.sh_ script are specified 
in the _environments/template/environment.conf_ file. Generated secrets will be stored in the environment's directory in the 
"password", "secret", "ssl_cert" or "saml_cert" directory, depending on the type of secret. To use the secret
in a playbook it must be read from disk. For this the Jinja2 "lookup" function can be used. E.g. to read the "some_password" 
password from the "password" directory in the environment:

    "{{ lookup('file', inventory_dir+'/password/some_password') }}"
    
While you could use this directly in your templates or Ansible tasks, for readability, it is recommended to create a variable 
fot the secret in group_vars. Assuming you have a "middleware" role, the group_vars/middleware.yml in your environment could contain:

    # Password for the middleware management API
    middleware_management_api_password: "{{ lookup('file', inventory_dir+'/password/middleware_management_api') }}"
    
    # Middleware encryption secret
    middleware_encryption_secret: "{{ lookup('file', inventory_dir+'/secret/middleware') }}"
    
    # Format: PEM RSA PRIVATE KEY
    middleware_ssl_key: "{{ lookup('file', inventory_dir+'/ssl_cert/middleware.key') }}"
    
    # Format: PEM X.509 Certificate (chain)
    # Order: SSL Server certificate followed by intermediate certificate(s) in chain order.
    # Do not include root CA certificate
    middleware_ssl_certificate: "{{ lookup('file', inventory_dir+'/ssl_cert/middleware.crt') }}"
    
    # Format: PEM RSA PRIVATE KEY
    middleware_saml_sp_privatekey: "{{ lookup('file', inventory_dir+'/saml_cert/middleware_saml_sp.key') }}"
    
    # Format: PEM X.509 certificate
    middleware_saml_sp_publickey: "{{ lookup('file', inventory_dir+'/saml_cert/middleware_saml_sp.crt') }}"
    
Now you can use these variables in your tasks and templates. E.g.

    - name: Put SSL certificate for middleware
      copy: content="{{ middleware_ssl_certificate }}" dest=/etc/nginx/middleware.crt
      notify:
          - restart nginx

    - name: Put SSL private key for middleware
      copy: content="{{ middleware_ssl_key }}" dest=/etc/nginx/middleware.key owner=root mode=400
      notify:
          - restart nginx

## Encrypting secrets
An [environment](#environment) will typically contain secrets like passwords, private keys. Ansible-tools can use a vault 
to store these secrets in encrypted form in the environment. A vault uses a symmetric key to encrypt and decrypt secrets 
so only this key has to be protected. This allows the encrypted values to be put under version control like the rest 
of the environment.

The included "create_new_environment.sh" script can be used to create the encryption key for an environment and to
generate the secrets required by the environment in one go. The specification for the secrets to create and whether 
to use encryption in configured in the "environment.conf" in the template.

When talking about a **vault** in the rest of this document this refers to the way ansible-tools uses keyczar to work 
with encrypted values, not the Ansible playbook vault.

### Required tools

To use the vault python-keyczar must be installed. Use `pip install python-keyczar` to install this tool.

### Enabling encryption

To enable encryption of secrets set "USE_KEYSZAR=1" in _environments/template/environment.conf_. Any new password,
secrets or private keys generated by the "create_new_environment.sh" will be encrypted. Existing secrets will not be 
changed. To create encrypted secrets you can delete the exiting ons and rerun the script, or you can encrypt them
manually using the _encrypt-file.sh_ script. 

E.g to output the encrypted contents of "environments/password/some_password":

`$ ./scripts/encrypt-file.sh environment/local/ansible-keystore -f environments/password/some_password`

The encrypted secrets, password and certificates to be created by the _create_new_environment.sh_ script are specified 
in the _environments/template/environment.conf_ file. Generated secrets will be stored in the environment in the 
"password", "secret", "ssl_cert" or "saml_cert" directory, depending on type.

You must update your playbooks to decrypt the secrets. The ansible-tools example playbook already set a variable "vault_keydir" in 
_group_vars/all.yml_ that points to the keyczar keyset for decrypting secrets: `vault_keydir: "{{ inventory_dir }}/ansible-keystore"`.

We assume that you are loading your secrets in (group) variables as described [above](#using_secrets).

To decrypt a secret so it can be used in an Ansible playbook you use the custom Jinja2 filter "vault". This filter 
expects one argument: the location of the keyset to use to decrypt the secret.

Example of an Ansible task that is not using encrypted passwords:

    - name: add mariadb backup user
      mysql_user:
        name: "{{ mariadb_backup_user }}"
        password: "{{ mariadb_backup_password }}"
        login_user: root
        login_password: "{{ mariadb_root_password }}"
        priv: "*.*:SELECT"
        state: present
      when: mariadb_enable_remote_ssh_backup | default(false)

Example of the same task that is using encrypted passwords:

    # Task that is using encrypted passwords
    - name: add mariadb backup user
      mysql_user:
        name: "{{ mariadb_backup_user }}"
        password: "{{ mariadb_backup_password | vault(vault_keydir) }}"
        login_user: root
        login_password: "{{ mariadb_root_password | vault(vault_keydir) }}"
        priv: "*.*:SELECT"
        state: present
      when: mariadb_enable_remote_ssh_backup | default(false)
 
### Keyset

When "USE_KEYCZAR=1" in _environments/template/environment.conf_ the "create_new_environment.sh" script will create a 
keyset for the environment. This keyset contains the secret key that is used to encrypt and decrypt secrets. An existing 
keyset will not be overwritten.

### Creating an encrypted secret

Several utility scripts are provided to create encrypted secrets:

* An existing secret in a file can be encrypted using _encrypt-file.sh_ script.
  E.g. to encrypt the contents of "/file/with/plaintext/secret" and store it in "environment/secrets/encrypted_secret":

    `$ ./scripts/encrypt-file.sh environment/local/ansible-keystore -f /file/with/plaintext/secret > environment/secrets/encrypted_secret`

* A new random password can be generated using the _gen_password.sh_ script.
  E.g. to generate a new 15 character long encrypted password in "environment/passwords/encrypted_password":
  
    `$ ./scripts/gen_password.sh 15 environment/local/ansible-keystore > environment/secrets/encrypted_secret`

### Decrypting an encrypted file

An encrypted file can be decrypted using the "-d" option to the _encrypt-file.sh_ script.
E.g. to output the decrypted contents of "environment/password/some_password":

`$ ./scripts/encrypt-file.sh -d environment/local/ansible-keystore -f environment/password/some_password`
