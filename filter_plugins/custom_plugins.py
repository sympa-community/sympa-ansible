# Copyright 2015 SURFnet B.V.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Custom filter plugins for use with Ansible.
# Defines two filters: "vault" and "depem"

# Filter: "vault"
# Example: {{ foo | vault(vault_keydir) }}
# Decrypts the contents of the Ansible variable "foo" with the keyczar key that is stored in the
# directory specified in the Ansible "vault_keydir" variable

# Filter: "depem"
# Example: {{ foo | depem }}
# Remove the PEM headers and whitespace from a string. When used on a PEM encoded X.509 certificate this
# will leave just the base64 encoded part, ready to use in e.g. a XML dsig X509Certificate element.


# decrypt string "encrypted: using key stored in "keydir".
def vault(encrypted, keydir):
    method = """
from keyczar import keyczar
import os.path
import sys

expanded_keydir = os.path.expanduser("%s")
crypter = keyczar.Crypter.Read(expanded_keydir)
sys.stdout.write(crypter.Decrypt("%s"))
    """ % (keydir, encrypted)
    from subprocess import check_output
    return check_output(["python", "-c", method])


# Strip PEM headers and remove all whitespace from "string"
def depem(string):
    import re
    return re.sub(r'\s+|(-----(BEGIN|END).*-----)', '', string)


class FilterModule(object):

    def filters(self):
        return {
            'vault': vault,
            'depem': depem,
        }
