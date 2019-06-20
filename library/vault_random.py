#! /usr/bin/python3

from ansible.module_utils.basic import *

import random
import string
import yaml

from ansible import constants as C
from ansible.constants import DEFAULT_VAULT_ID_MATCH
from ansible.parsing.vault import VaultLib
from ansible.parsing.vault import VaultSecret

from ansible.cli import CLI
from ansible.cli.vault import VaultCLI
from ansible.parsing.dataloader import DataLoader

# notes
# use same default for length as password module

def run_module():
    module_args = dict(
        src=dict(type='str'),
        dest=dict(type='str'),
        password_file=dict(type='str', no_log=True),
        vartree=dict(type='dict', required=True),
        length=dict(type='int', required=False, default=20),
    )

    result = dict(
        changed=False,
    )
    
    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    if module.params['password_file']:
        # check if password file exists
        if not os.path.exists(module.params['password_file']):
            create_password_file(module.params['password_file'])
            result['changed']=True

    # setup vault

    loader = DataLoader()

    if module.params['password_file']:
        vault_secret = CLI.setup_vault_secrets(
            loader=loader,
            vault_ids=C.DEFAULT_VAULT_IDENTITY_LIST,
            vault_password_files=[module.params['password_file']]
        )
    else:    
        vault_secret = CLI.setup_vault_secrets(
            loader=loader,
            vault_ids=C.DEFAULT_VAULT_IDENTITY_LIST
        )

    vault = VaultLib(vault_secret)
    vault_cli = VaultCLI(dict())
    
    # read input file
    if module.params['src']:
        print(module.params['src'])
        with open(module.params['src'], 'r') as stream:
            try:
                input = yaml.safe_load(stream)
            except yaml.YAMLError as exc:
                print("YAML is broken.")
                print(exc)
        
    else:
        input = module.params['vartree']


    walk_input(vault, vault_cli, input, module.params)
    yaml_out = yaml.dump(input, default_flow_style=False)

    # # setup vault
    # loader = DataLoader()
    # vault_secret = CLI.setup_vault_secrets(
    #         loader=loader,
    #         vault_ids=C.DEFAULT_VAULT_IDENTITY_LIST
    # )
    # vault = VaultLib(vault_secret)

    # encrypt it
#    vault_out=vault.encrypt(yaml_out)

    # write to file
    ansible_facts_val = dict(
        vault_secrets=module.params['vartree'],
    )
    
    response = {
            "NAME": module.params['vartree'],
#            "FILE": yaml_out,
#            "VAULT": vault_out,
#            "LENGTH": module.params['length'],
#        module.params['vartree'],
    }

    module.exit_json(changed=result['changed'], ansible_facts=ansible_facts_val, vartree=module.params['vartree'])

# populates leave entries with None value
def walk_input(vault, vault_cli, node, params):
    for key, item in node.items():
        if isinstance(item,dict):
            walk_input(vault, vault_cli,item, params)
        elif item is None:
            node[key] = vault_cli.format_ciphertext_yaml(vault.encrypt(random_password(params['length'])))

# create password file
def create_password_file(filename):
    original_umask = os.umask(0o177)  # 0o777 ^ 0o600
    try:
        password_fh = os.fdopen(os.open(filename, os.O_WRONLY | os.O_CREAT, 0o600), 'w')
    finally:
        os.umask(original_umask)

    password_fh.write(random_password())
    password_fh.close()

# generates random passwords
def random_password(length=20):
    letters = string.ascii_letters
    return ''.join(random.choice(letters) for i in range(length))

def main():
    run_module()

if __name__ == '__main__':
        main()
