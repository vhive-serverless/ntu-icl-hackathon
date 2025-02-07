#!/bin/bash

# README:
# 1. Run this before 'rsync'. This is becasue we want to create a unique key for admins and then put this in every node
# 2. 'create_admins.sh' will use these keys later on every node.

USER1="admin_user1"
USER2="admin_user2"
KEY_DIR="admin_keys"

# Create keys directory if it doesn't exist
mkdir -p "$KEY_DIR"

# Create SSH key pairs for both users
ssh-keygen -t rsa -b 4096 -f "${KEY_DIR}/${USER1}_key" -N ""
ssh-keygen -t rsa -b 4096 -f "${KEY_DIR}/${USER2}_key" -N ""

# Set appropriate permissions
sudo chmod 600 "${KEY_DIR}/${USER1}_key" "${KEY_DIR}/${USER2}_key"
sudo chmod 644 "${KEY_DIR}/${USER1}_key.pub" "${KEY_DIR}/${USER2}_key.pub"