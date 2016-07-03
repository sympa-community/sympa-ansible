#!/bin/bash

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

# Generate a plaintext password

# If a keyczar directory is provided, the password is output encrypted as well.

if [ $# -lt 1 ]; then
    echo "Usage $0 <password length in characters> [keyvault for encrypting private key]"
    exit 1
fi

if [ $1 -eq "0" ]; then
    password=''
elif [ $1 -gt "0" ]; then
    password=`env LC_CTYPE=C LC_ALL=C tr -dc "a-zA-Z0-9-_" < /dev/urandom | head -c $1`
else
    echo "password length must be >= 0"
    exit 1
fi

if [ -d "$2" ]; then
    tempfile=`mktemp -t genpass.XXXXX`
    echo -n ${password} > "$tempfile"    
    `dirname $0`/encrypt-file.sh "$2" -f "$tempfile"
    if [ $? -ne "0" ]; then
        echo "Encryption failed"
        rm "$tempfile"
        exit 1
    fi
    rm "$tempfile"
else
    echo $password
fi
