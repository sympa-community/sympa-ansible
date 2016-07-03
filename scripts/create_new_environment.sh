#!/bin/bash

# Copyright 2015, 2016 SURFnet B.V.
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


# Creates a new environment that can be used with your Ansible playbooks based on a template
# environment. The script can be rerun in an existing environment and will not overwrite existing
# files. Please read the notice at the end of the script

# The configuration is read from a file called "environment.conf" that must be located in the template directory

CWD=`pwd`
BASEDIR=`dirname $0`

function error_exit {
    echo "${1}"
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

BASEDIR=`realpath ${BASEDIR}`

# Default template dir
TEMPLATE_DIR="${BASEDIR}/../environments/template"

# Process options
ENVIRONMENT_DIR=$1
shift
if [ -z "${ENVIRONMENT_DIR}"  ]; then
    echo "Usage: $0 <environment directory> [--template <template directory>]"
    echo "
Creates or updates an Ansible 'enviroment' from a template, generating certificates and passwords as specified in the
'environment.conf' file in the template. The <environment directory> is created if it does not exists. Existing files in
the <environment directory> will never be changed by this script.

The <template directory> defaults to: '../environments/template' relative to the script. Use the '--template' option
to specify an alternate location.
"
    exit 1;
fi
ENVIRONMENT_NAME=`basename ${ENVIRONMENT_DIR}`

# Process option(s)
while [[ $# > 0 ]]
do
option="$1"
shift
case $option in
    -t|--template)
    TEMPLATE_DIR="$1"
    if [ -z "$1" ]; then
        error_exit "--template option requires argument"
    fi
    shift
    ;;
    *)
    error_exit "Unknown option: '${option}'"
    ;;
esac
done

TEMPLATE_DIR=`realpath ${TEMPLATE_DIR}`
if [ $? -ne "0" ]; then
    error_exit "Could not find template dir"
fi
echo "Using template from: ${TEMPLATE_DIR}"


# Read environment.conf from template directory
ENVIRONMENT_CONF="${TEMPLATE_DIR}/environment.conf"
if [ ! -f "${ENVIRONMENT_CONF}" ]; then
    error_exit "Could not find 'environment.conf' in ${TEMPLATE_DIR}"
fi
echo "Reading configuration from: ${ENVIRONMENT_CONF}"
. "${ENVIRONMENT_CONF}"
echo "Done reading configuration"

# Fallback to USE_KEYCZAR misspelled as USE_KEYSZAR
if [ -z "${USE_KEYCZAR}" ]; then
    USE_KEYCZAR=${USE_KEYSZAR}
fi

if [ ! -e ${ENVIRONMENT_DIR} ]; then
    echo "Creating new environment directory"
    mkdir -p ${ENVIRONMENT_DIR}
fi

ENVIRONMENT_DIR=`realpath ${ENVIRONMENT_DIR}`
if [ $? -ne "0" ]; then
    error_exit "Could not change to environment dir"
fi
echo "Creating new environment in directory: ${ENVIRONMENT_DIR}"

# Copy inventory file into the new environment
INVENTORY_FILE=${ENVIRONMENT_DIR}/inventory
if [ ! -e  ${INVENTORY_FILE} ]; then
    echo "Creating inventory file"
    cp ${TEMPLATE_DIR}/inventory ${INVENTORY_FILE}
fi


# Copy directories from the template to the new environment
directories=("group_vars" "handlers" "tasks" "templates")
for directory in "${directories[@]}"; do
    if [ -e ${TEMPLATE_DIR}/${directory} ]; then
        if [ ! -e ${ENVIRONMENT_DIR}/${directory} ]; then
            echo "Creating/copying ${directory} directory"
            mkdir -p ${ENVIRONMENT_DIR}/${directory}
            if [ $? -ne "0" ]; then
                error_exit "Error creating ${directory} directory"
            fi
            cp -r ${TEMPLATE_DIR}/${directory}/* ${ENVIRONMENT_DIR}/${directory}
            if [ $? -ne "0" ]; then
                rm -r ${ENVIRONMENT_DIR}/${directory}
                error_exit "Error copying files to the ${directory} directory"
            fi
        else
            echo "Skipping creating/copying the ${directory} directory because it already exists"
        fi
    fi
done


KEY_DIR=""
if [ "${USE_KEYCZAR}" -eq 1 ]; then
    # Create keystore for encypting secrets
    KEY_DIR=${ENVIRONMENT_DIR}/${KEYSTORE_DIR}

    if [ ! -e ${KEY_DIR} ]; then
        ${BASEDIR}/create_keydir.sh ${KEY_DIR}
        if [ $? -ne "0" ]; then
            error_exit "Error creating keyset"
        fi
    fi
    echo "Using keydir: ${KEY_DIR}"
else
    echo "Not using keyczar. Keys and passwords will be stored in plaintext"
fi


# Generate passwords
if [ ${#PASSWORDS[*]} -gt 0 ]; then
    PASSWORD_DIR=${ENVIRONMENT_DIR}/password
    if [ ! -e ${PASSWORD_DIR} ]; then
        echo "Creating password directory"
        mkdir -p ${PASSWORD_DIR}
    fi

    for pass in "${PASSWORDS[@]}"; do
        if [ ! -e "${PASSWORD_DIR}/${pass}" ]; then
            echo "Generating password for ${pass}"
            generated_password=`${BASEDIR}/gen_password.sh ${PASSWORD_LENGTH} ${KEY_DIR}`
            if [ $? -ne "0" ]; then
                error_exit "Error generating password"
            fi
            echo "${generated_password}" > ${PASSWORD_DIR}/${pass}
        else
            echo "Password ${pass} exists, skipping"
        fi
    done
    if [ ! -e "${PASSWORD_DIR}/empty_placeholder" ]; then
        echo "Creating empty_placeholder password"
        generated_password=`${BASEDIR}/gen_password.sh 0 ${KEY_DIR}`
        if [ $? -ne "0" ]; then
            error_exit "Error creating password"
        fi
        echo "${generated_password}" > ${PASSWORD_DIR}/empty_placeholder
    fi
else
    echo "Skipping generation of passwords because none are defined in the environment.conf"
fi


# Generate secrets
if [ ${#SECRETS[*]} -gt 0 ]; then
    SECRET_DIR=${ENVIRONMENT_DIR}/secret
    if [ ! -e ${SECRET_DIR} ]; then
        echo "Creating secret directory"
        mkdir -p ${SECRET_DIR}
    fi

    for secret in "${SECRETS[@]}"; do
        if [ ! -e "${SECRET_DIR}/${secret}" ]; then
            echo "Generating secret for ${secret}"
            generated_secret=`${BASEDIR}/gen_password.sh ${SECRET_LENGTH} ${KEY_DIR}`
            if [ $? -ne "0" ]; then
                error_exit "Error generating secret"
            fi
            echo "${generated_secret}" > ${SECRET_DIR}/${secret}
        else
            echo "Secret ${secret} exists, skipping"
        fi
    done
else
    echo "Skipping generation of secrets because none are defined in the environment.conf"
fi


# Generate self-signed certs for SAML use
if [ ${#SAML_CERTS[*]} -gt 0 ]; then
    SAML_CERT_DIR=${ENVIRONMENT_DIR}/saml_cert
    if [ ! -e ${SAML_CERT_DIR} ]; then
        echo "Creating saml_cert directory"
        mkdir -p ${SAML_CERT_DIR}
    fi

    cd ${SAML_CERT_DIR}
    for cert in "${SAML_CERTS[@]}"; do
        cert_name=${cert%%:*}
        cert_dn=${cert#*:}
        if [ ! -e "${SAML_CERT_DIR}/${cert_name}.crt" -a "${SAML_CERT_DIR}/${cert_name}.key" ]; then
            echo "Creating SAML signing certificate and key for ${cert_name}; DN: ${cert_dn}"
            ${BASEDIR}/gen_selfsigned_cert.sh ${cert_name} "${cert_dn}" ${KEY_DIR}
            if [ $? -ne "0" ]; then
                error_exit "Error creating SAML signing certificate"
            fi
        else
            echo "SAML signing certificate ${cert_name} exists, skipping"
        fi
    done
    cd ${CWD}
else
    echo "Skipping generation of self-signed certificates because none are defined in the environment.conf"
fi

# Create SSL server certificates
if [ ${#SSL_CERTS[*]} -gt 0 ]; then
    # Create Root CA for issueing SSL Server certs
    CA_DIR=${ENVIRONMENT_DIR}/ca
    if [ ! -e ${CA_DIR} ]; then
        echo "Creating Root CA with DN: ${SSL_ROOT_DN}"
        ${BASEDIR}/create_ca.sh ${CA_DIR} "${SSL_ROOT_DN}"
        if [ $? -ne "0" ]; then
            error_exit "Error creating CA"
        fi
    fi

    # Create SSL server certificates
    SSL_CERT_DIR=${ENVIRONMENT_DIR}/ssl_cert
    if [ ! -e ${SSL_CERT_DIR} ]; then
        echo "Creating ssl_cert directory"
        mkdir -p ${SSL_CERT_DIR}
    fi

    cd ${SSL_CERT_DIR}
    for cert in "${SSL_CERTS[@]}"; do
        cert_name=${cert%%:*}
        cert_dn=${cert#*:}
        if [ ! -e "${SSL_CERT_DIR}/${cert_name}.crt" -a "${SSL_CERT_DIR}/${cert_name}.key" ]; then
            echo "Creating SSL certificate and key for ${cert_name}; DN: ${cert_dn}"
            ${BASEDIR}/gen_ssl_server_cert.sh ${CA_DIR} ${cert_name} "${cert_dn}" ${KEY_DIR}
            if [ $? -ne "0" ]; then
                error_exit "Error creating SSL certificate"
            fi
        else
            echo "SSL certificate ${cert_name} exists, skipping"
        fi
    done
    cd ${CWD}
else
    echo "Skipping generation of the CA and certificates because none are defined in the environment.conf"
fi


# Generate SSH keys
if [ ${#SSH_KEYS[*]} -gt 0 ]; then
    SSH_KEY_DIR=${ENVIRONMENT_DIR}/ssh
    if [ ! -e ${SSH_KEY_DIR} ]; then
        echo "Creating ssh directory"
        mkdir -p ${SSH_KEY_DIR}
    fi

    cd ${SSH_KEY_DIR}
    for key in "${SSH_KEYS[@]}"; do
        if [ ! -e "${SSH_KEY_DIR}/${key}.pub" -a "${SSH_KEY_DIR}/${key}.key" ]; then
            echo "Generating ssh keypair for ${key}"
            ${BASEDIR}/gen_ssh_key.sh ${key} ${KEY_DIR}
            if [ $? -ne "0" ]; then
                error_exit "Error generating SSH keypair"
            fi
        else
            echo "SSH keypair ${key} exists, skipping"
        fi
    done
    cd ${CWD}
else
    echo "Skipping generation of ssh keys because none are defined in the environment.conf"
fi


echo
echo "Created (or updated) passwords, secrets, certificates and/or ssh keys for the new environment as specified in
the environment.conf: ${ENVIRONMENT_CONF}
It is save to rerun this script as it will not overwrite existing files."
if [ ${USE_KEYCZAR} -eq 1 ]; then
echo "
* All secrets (except the CA private key) are encrypted with a symmetic key that is stored in a \"vault\". The vault is
  located in ${KEY_DIR}

* You can use the encrypt.sh and encrypt-file.sh scripts to encrypt and decrypt the secrets.

* For productions (like) systems it is advisable to keep this key separate from the environment. To do this:
  1) Move the '${KEYSTORE_DIR}' to another location
  2) Update vault_keydir in group_vars/all.yml to point to the new location
  Note that rerunning this script after moving the key will result in a new key being created, which is probably
  undesired.
"
fi
if [ ${#SSL_CERTS[*]} -gt 0 ]; then
echo "
* Certificate authority
  The CA directory (${CA_DIR})
  contains the CA that is/was used for generating SSL server certificates. This CA is intended for testing purposes
  only.
  The private key of the CA is stored *unencrypted* in ca-key.pem the CA directory. The CA directory is not required
  for running the ansible playbooks."
fi
echo "
* Complete the configuration of the environment by
  - updating the inventory file
  - updating the the .yml files with variables in the group_vars directory
  - updating the files in the templates directory
"

if [ ${#PASSWORDS[*]} -gt 0 ]; then
    echo "The generated passwords are stored in: ${PASSWORD_DIR}"
fi
if [ ${#SECRETS[*]} -gt 0 ]; then
   echo "The generated secrets are stored in: ${SECRET_DIR}"
fi
if [ ${#SAML_CERTS[*]} -gt 0 ]; then
   echo "The generated self-signed certificates are stored in: ${SAML_CERT_DIR}"
fi
if [ ${#SSL_CERTS[*]} -gt 0 ]; then
   echo "The generated SSL/TLS server certificates are stored in: ${SSL_CERT_DIR}"
fi
if [ ${#SSH_KEYS[*]} -gt 0 ]; then
   echo "The generated ssh keypairs are stored in: ${SSH_KEY_DIR}"
fi
