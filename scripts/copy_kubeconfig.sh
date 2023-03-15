#!/bin/bash

# exit on errors
set -e

config_path=${1:-"${HOME}/.kube/config"}

[[ -z "${SSH_USER}" ]] && export SSH_USER="vagrant"
[[ -z "${SSH_USER_PASS}" ]] && export SSH_USER_PASS="vagrant"
[[ -z "${SSH_PORT}" ]] && export SSH_PORT="2222"
[[ -z "${SSH_HOST}" ]] && export SSH_HOST="127.0.0.1"

echo "[INFO] connecting to ${SSH_USER}@${SSH_HOST}:${SSH_PORT}.."
vagrant ssh -c "sudo install -C -m 600 -o vagrant -g vagrant /etc/rancher/k3s/k3s.yaml ~/config" >/dev/null 2>&1

echo "[INFO] connection success.."

if [[ ! -d "$(dirname "${config_path}")" ]]; then
    echo "[WARNING] $(dirname "${config_path}") doesn't exist. creating.."
    mkdir -p "$(dirname "${config_path}")"
fi

if [[ -f "${config_path}" ]]; then
    echo "[WARNING] ${config_path} already exists"
    echo "[INFO] backing up ${config_path} to ${HOME}/config.backup.$(date +%s).."
    cp "${config_path}" "${HOME}/config.backup.$(date +%s)"
fi

echo "[INFO] copying k3s kubeconfig to ${config_path}"
sshpass -p "${SSH_USER_PASS}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}":~/config "${config_path}" >/dev/null 2>&1

# remove config file from guest machine vagrant home directory
vagrant ssh -c "rm -rf ~/config" >/dev/null 2>&1

echo "[INFO] you can now access k3s cluster locally, run:"
echo "    $ kubectl version"
