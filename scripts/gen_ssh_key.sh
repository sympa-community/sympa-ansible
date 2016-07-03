#!/bin/bash

# Copyright 2016 SURFnet B.V.
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

# Generate a SSH keypair in the current directory
# Base name. Base name for public and private key
# Creates private key "<basename>.key" and public key "<basename>.pub"

# If a keyczar directory is provided, the private key that is output is encrypted.

RSA_MODULUS_SIZE_BITS=4096
CWD=`pwd`
BASEDIR=`dirname $0`

function error_exit {
    echo "${1}"
    if [ -d ${tmpdir} ]; then
        rm -r ${tmpdir}
    fi
    cd ${CWD}
    exit 1
}

if [ $# -lt 1 ]; then
    echo "Usage $0 <basename> [keyvault for encrypting private key]"
    exit 1
fi

KEY_BASENAME=${1}
KEY_DIR=${2}

if [ -e ${KEY_BASENAME}.key -o -e ${KEY_BASENAME}.pub ]; then
    echo "'${KEY_BASENAME}.key' or '${KEY_BASENAME}.pub' already exist. Leaving"
    exit 1;
fi

SSH_KEYGEN=`which ssh-keygen`
if [ -z "${SSH_KEYGEN}" -o ! -x ${SSH_KEYGEN} ]; then
    echo "ssh-keygen is not in path or not executable. Please install ssh-keygen"
    exit 1;
fi
echo "Using ssh-keygen: ${SSH_KEYGEN}"

tmpdir=`mktemp -d -t sshkg.XXXXX`
if [ $? -ne "0" ]; then
    error_exit "Error creating TMP dir"
fi

# Generate RSA private/public keypair with RSA_MODULUS_SIZE_BITS bit modulus
${SSH_KEYGEN} -t rsa -b ${RSA_MODULUS_SIZE_BITS} -N "" -C "${KEY_BASENAME}" -f ${tmpdir}/id_rsa
if [ $? -ne "0" ]; then
    error_exit "Error generating ssh keypair"
fi

if [ -d "${KEY_DIR}" ]; then
    crypted_private_key=`${BASEDIR}/encrypt-file.sh "${KEY_DIR}" -f "${tmpdir}/id_rsa"`
    if [ $? -ne "0" ]; then
        error_exit "Error crypting private key"
    fi
    echo "${crypted_private_key}" > ${KEY_BASENAME}.key
    if [ $? -ne "0" ]; then
        error_exit "Error writing private key"
    fi

else
    cp ${tmpdir}/id_rsa ${KEY_BASENAME}.key
    if [ $? -ne "0" ]; then
        error_exit "Error writing private key"
    fi

fi

# Copy public key
cp ${tmpdir}/id_rsa.pub ${KEY_BASENAME}.pub
if [ $? -ne "0" ]; then
    error_exit "Error writing public key"
fi

rm -r ${tmpdir}

exit 0

