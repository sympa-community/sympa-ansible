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

# Initialize a new keyczart directory with an encryption key

CWD=`pwd`
BASEDIR=`dirname $0`

function error_exit {
    echo "${1}"
    rm -r ${KEY_DIR}
    cd ${CWD}
    exit 1
}

function realpath {
    if [ ! -d ${1} ]; then
        return 1
    fi
    current_dir=`pwd`
    cd ${1}
    res=$?
    if [ $? -eq "0" ]; then
        path=`pwd`
        cd $current_dir
        echo $path
    fi
    return $res
}

KEYCZART=`which keyczart 2>/dev/null`
if [ -z "${KEYCZART}" -o ! -x "${KEYCZART}" ]; then
    echo "keyczart is not in path or not executable. Please install keyczart"
    echo "See: http://keyczar.org"
    exit 1;
fi

echo "Using keyczart: ${KEYCZART}"

# Process options
KEY_DIR=$1
if [ -z "${KEY_DIR}"  ]; then
    echo "Usage: $0 <key directory>"
    exit 1;
fi

if [ -e ${KEY_DIR} ]; then
    echo "Key directory already exists. Leaving"
    exit 1;
fi

echo "Creating keydir"
mkdir -p -v ${KEY_DIR}
if [ $? -ne "0" ]; then
    echo "Error creating keydir"
    exit 1
fi

KEY_DIR=`realpath ${KEY_DIR}`
echo "Using keydir: ${KEY_DIR}"

echo "Creating keyset with name 'Ansible'"
# Create new, empty, keyset
${KEYCZART} create --location=${KEY_DIR} --purpose=crypt --name=Ansible
if [ $? -ne "0" ]; then
    error_exit "Error creating keyset"
fi

echo "Adding new key"
# Generate new key, add it to the keyset, and set this to be the active key
${KEYCZART} addkey --location=${KEY_DIR} --status=primary
if [ $? -ne "0" ]; then
    error_exit "Error adding key"
fi

echo "Done. Created new key and keyset: ${KEY_DIR}"

exit 0
