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
import sys
from optparse import OptionParser
from keyczar import keyczar

parser = OptionParser(usage="usage: %prog [options] <keyczar keystore directory>")
parser.add_option("-f", "--file", help="the input file", dest="filename", metavar="FILE")
parser.add_option("-d", "--decrypt", action="store_true", help="decrypt the file", dest="decrypt")

(options, args) = parser.parse_args()

if len(args) != 1:
  parser.error("wrong number of arguments")

if not os.path.isdir(args[0]):
  print 'Error: keystore directory "%s" not found' % args[0]
  sys.exit(1)

if options.filename:
  with open(options.filename, 'r') as content_file:
    content = content_file.read()
    keydir = os.path.expanduser(args[0])
    crypter = keyczar.Crypter.Read(keydir)
    if options.decrypt:
      print crypter.Decrypt(content)
    else:
      encrypted_secret = crypter.Encrypt(content)
      print encrypted_secret
else:
  parser.print_help()

