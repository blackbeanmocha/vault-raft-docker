#!/bin/bash

role=$1
echo "User given role: $role"

key_file="/vault/keys/key.txt"

# create raft folder
mkdir -p /vault/raft

# Find docker container IP
vault_docker_ip=$(hostname -i)
echo "Container IP Address: $vault_docker_ip"

# replace vault config with docker IP
sed -i "s/127.0.0.1/$vault_docker_ip/g" /vault/config/vault-config.json

export VAULT_ADDR=http://$vault_docker_ip:8200

# Install curl
apk add curl

# turn on bash's job control
set -m

#start vault and move it to background
vault server -config=/vault/config/vault-config.json -log-level=debug &

while ! nc -z $vault_docker_ip 8200; do
  echo "Inside vault mgr: Waiting for vault to be available on $vault_docker_ip 8200"
  sleep 1
done

if [ $role == "master" ]; then
  echo "Inside vault mgr: --------- master -----------------"

  #save master_ip
  echo "$vault_docker_ip" > "$master_ip"

  #Initialize vault
  echo "Inside vault mgr: Initialize vault"
  vault operator init -key-shares=1 -key-threshold=1 > $key_file

  while [ $(curl -s -o /dev/null -w '%{http_code}' http://$vault_docker_ip:8200/v1/sys/health) != 503 ]; do
    echo 'Vault is initializing...'
    sleep 2
  done

  # Unseal vault
  echo "Inside vault mgr: unseal vault"
  vault operator unseal $(grep 'Key 1:' $key_file | awk '{print $NF}')

  while [ $(curl -s -o /dev/null -w '%{http_code}' http://$vault_docker_ip:8200/v1/sys/health) != 200 ]; do
    echo 'Vault is unsealing...'
    sleep 2
  done

else
  echo "Inside vault mgr: --------- follower -----------------"

  mip="vault1"

  # Verify master vault is ready
  while [ $(curl -s -o /dev/null -w '%{http_code}' http://$mip:8200/v1/sys/health) != 200 ]; do
    echo 'Master vault is not ready yet...'
    sleep 2
  done

  # Join raft cluster
  vault operator raft join http://$mip:8200
  sleep 10

  # Unseal vault
  vault operator unseal $(grep 'Key 1:' $key_file | awk '{print $NF}')
  while [ $(curl -s -o /dev/null -w '%{http_code}' http://$vault_docker_ip:8200/v1/sys/health) != 429 ]; do
    echo 'Follower Vault is unsealing...'
    sleep 2
  done

  vault login $(grep 'Initial Root Token:' $key_file | awk '{print $NF}')
  vault operator raft list-peers
fi

fg %1
