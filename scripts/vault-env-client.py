#!/usr/bin/env python
# -*- coding: utf-8 -*-
# (c) 2014, Matt Martz <matt@sivel.net>
# (c) 2016, Justin Mayer <https://justinmayer.com/>
# This file is part of Ansible.
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.

ANSIBLE_METADATA = {'status': ['preview'],
                    'supported_by': 'community',
                    'version': '0.1'}

import argparse
import getpass
import os
import sys

from ansible.config.manager import ConfigManager

KEYNAME_UNKNOWN_RC = 2


def build_arg_parser():
    parser = argparse.ArgumentParser(description='Get a vault password from user keyring')

    parser.add_argument('--vault-id', action='store', default=None,
                        dest='vault_id',
                        help='name of the vault secret to get from keyring')
    parser.add_argument('--username', action='store', default=None,
                        help='the username whose keyring is queried')
    parser.add_argument('--set', action='store_true', default=False,
                        dest='set_password',
                        help='set the password instead of getting it')
    return parser


def main():
    config_manager = ConfigManager()
    username = config_manager.data.get_setting('vault.username')
    if not username:
        username = getpass.getuser()

    keyname = config_manager.data.get_setting('vault.keyname')
    if not keyname:
        keyname = 'ansible'

    arg_parser = build_arg_parser()
    args = arg_parser.parse_args()

    username = args.username or username
    keyname = args.vault_id or keyname

    # lookup the file
    if os.path.exists('environments/local/vault-password'):
        with open('environments/local/vault-password', 'r') as stream:
            sys.stdout.write('%s\n' % stream.readline())
            sys.exit(0)
    else:
        # provide fake password
        sys.stdout.write('%s\n' % 'nevairbe')
        sys.exit(0)

    sys.exit(0)


if __name__ == '__main__':
    main()
