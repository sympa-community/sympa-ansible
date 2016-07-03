#!/usr/bin/env python

# Copyright 2014,2015 SURFnet B.V.
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

import os.path
import getpass
import sys
from optparse import OptionParser
from keyczar import keyczar

parser = OptionParser(usage="usage: %prog [options] <keyczar keystore directory>")
parser.add_option("-d", "--decrypt", action="store_true", help="decrypt the input", dest="decrypt")

(options, args) = parser.parse_args()

if len(args) != 1:
  parser.error("wrong number of arguments")

if not os.path.isdir(args[0]):
  print 'Error: keystore directory "%s" not found' % args[0]
  sys.exit(1)

keydir = os.path.expanduser(args[0])
crypter = keyczar.Crypter.Read(keydir)

if options.decrypt:
  encrypted_input = raw_input("Type the encrypted string: ")
  print 'The decrypted secret: %s' % crypter.Decrypt(encrypted_input)
else:
  password = getpass.getpass('Type the secret you want to encrypt: ')
  encrypted_secret = crypter.Encrypt(password)
  print 'The encrypted secret: %s' % encrypted_secret
