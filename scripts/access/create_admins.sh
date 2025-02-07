#!/bin/bash

# README:
# 1. This script assumes the existence of 'kubeconfig-admin' file in the 'configs' directory.
# 2. Two new admins and existing accounds will use the same kubeconfig file.


# Check if at least one IP is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 node_name [node_name ...]"
    exit 1
fi

# Store names in an array
NODE_NAMES=("$@")

# Create ntu-cloud group if it doesn't exist
groupadd -f ntu-cloud

# Two new admin accounts
USER1="admin_user1"
USER2="admin_user2"

# Create users and add them to ntu-cloud group
useradd -m -s /bin/bash -g ntu-cloud "$USER1"
useradd -m -s /bin/bash -g ntu-cloud "$USER2"

# (Optional) Set passwords for these new accounts
# passwd "$USER1"
# passwd "$USER2"

# Generate SSH keys for admin users
for U in "$USER1" "$USER2"; do
    mkdir -p /home/"$U"/.ssh
    # Generate SSH key without passphrase
    su - "$U" -c "ssh-keygen -t ed25519 -f /home/$U/.ssh/id_ed25519 -N ''"
    # Set proper permissions
    chown -R "$U":"$U" /home/"$U"/.ssh
    chmod 700 /home/"$U"/.ssh
    chmod 600 /home/"$U"/.ssh/*
done

# Copy public keys to all nodes
for NAME in "${NODE_NAMES[@]}"; do
    for U in "$USER1" "$USER2"; do
        # Create user and add to ntu-cloud group on remote node
        ssh "$NAME" "groupadd -f ntu-cloud && useradd -m -s /bin/bash -g ntu-cloud $U"
        # Copy public key to remote node
        ssh "$NAME" "mkdir -p /home/$U/.ssh"
        scp /home/"$U"/.ssh/id_ed25519.pub "$NAME":/home/"$U"/.ssh/authorized_keys
    done
done

# Add admin accounts to sudoers (restricted)
sudo echo "$USER1 ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/99-ntu-cloud
sudo echo "$USER2 ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/99-ntu-cloud
sudo chmod 440 /etc/sudoers.d/99-ntu-cloud

# Copy kubeconfig to the new admin accounts and existing users
for U in "$USER1" "$USER2" "lkondras" "nehalem" "JunkeMao" "yulin001"; do
  sudo mkdir -p /home/"$U"/.kube
  sudo cp configs/kubeconfig-admin /home/"$U"/.kube/config
  sudo chown -R "$U":"$U" /home/"$U"/.kube
  sudo chmod 700 /home/"$U"/.kube
  sudo chmod 600 /home/"$U"/.kube/config
done

# Reduce access rights of all admin accounts' home directories
sudo chmod 750 /home/"$USER1" /home/"$USER2"