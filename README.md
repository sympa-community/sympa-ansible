# Sympa deployment with Ansible

[Sympa](http://www.sympa.org/) is an open source mailing list software

[Ansible](http://docs.ansible.com/) is an IT automation tool. It can configure systems, deploy software.

This project is based on [Ansible-tools](https://github.com/pmeulen/ansible-tools), an example of Ansible Playbooks organization focusing on deployment for multiple environments, articulation with [Vagrant](https://www.vagrantup.com/docs/), [keyczar](https://github.com/google/keyczar) based encryption. Ansible-tools demonstrates a way to use Ansible to effectively and securely manage multiple environments ranging from development to production using the same playbook.

# [Quickstart: Creating a development VM](id:quickstart)

First install the tools on your local machine:

* Install [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org). Virtualbox will run the development VM and Vagrant is used to create, configure and manage the development VM instance. **Vagrant 2 and later is required** (there is problems with previous versions).
* Install [Ansible](http://www.ansible.com). There are several ways to install Ansible. They are described in the [Ansible installation guide](http://docs.ansible.com/ansible/intro_installation.html). **Ansible 2.5 is required** for the _include-role_ feature to be used.

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

# Defining Sympa server setup 

The Sympa server parameters can be customized in the _environments/local/group_vars/sympa.yml_ file:


```
#!yaml

# Group vars for sympa servers

# FQDN for mail addresses
sympa_mail_hostname: lists.example.com

# FQDN of web interface
sympa_web_hostname: "{{ sympa_mail_hostname }}"

# Web server admin email
server_admin_email: "listmaster@{{ sympa_mail_hostname }}"

# Root directory to install Sympa software
sympa_root_directory: /home/sympa

# Email addresses of listmasters (comma separated)
sympa_listmaster_email: guevara@chemail.com

# Sympa database type (either "mysql" or "Pg")
sympa_db_type: "mysql"

# Root passwd for the Sympa database
sympa_db_root_password: "{{ lookup('file',inventory_dir+'/password/sympa_db_root_password') }}"

# App passwd for the Sympa database
sympa_db_app_password: "{{ lookup('file',inventory_dir+'/password/sympa_db_app_password') }}"

# SSL cert for Apache
sympa_ssl_certificate: "{{ lookup('file',inventory_dir+'/ssl_cert/webserver.crt') }}"

# SSL private key for Apache
sympa_ssl_key: "{{ lookup('file',inventory_dir+'/ssl_cert/webserver.key') }}"
```

Sympa virtual robots are enabled via YAML files, like _environments/local/sympa_virtual_robots/robot1.yml_ :

```
#!yaml

robot1:
  hostname: robot1.example.com
  title: Robot1 mailing list service
  create_list: listmaster
```


# Ansible-tools documentation

## Organisation

The _environments_ directory contains configuration elements specific to each target environment (local VM, dev, staging, production). This separation is what allows the configuration that is environment specific to be managed separately from the Ansible playbook(s) and roles. Environment specific configuration are things like Hostnames, IP addresses, Firewall rules, Email addresses, Passwords, private keys, certificates etc.

The other top level directories and files are:

- The _environments_ directory containing the template for a new environments
- The _scripts_ directory containing the various scripts used to create a new environment and manage secrets and work with
  the Vault
- A _Vagrantfile_ for creating a VM using Vagrant
- _ansible.cfg_ (optional) makes playbooks run faster by enabling SSH pipelining, 
- _provision-vagrant-vm.yml_ playbook used by the Vagrant provisioning step only.

## Creating a new environment
To get started you need an environment. Ansible-tools does not ship with a ready made environment, instead it ships with the tools to create new environments. In the environments directory of Ansible-tools you will find two directories:

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

Ansible-tools promotes a setup for encrypting secrets that is different from the 
[Ansible Vault](http://docs.ansible.com/ansible/playbooks_vault.html). The Ansible vault feature encrypts an entire 
.yml file with variable names and values, whereas the ansible-tools approach encrypts just the values en decrypts them 
just before they are needed. Both use the [python-keyczar](https://pypi.python.org/pypi/python-keyczar) for encryption.

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
