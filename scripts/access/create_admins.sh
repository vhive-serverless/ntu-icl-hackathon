#!/bin/bash

# README:
# 1. This script assumes the existence of 'kubeconfig-admin' file in the 'configs' directory.
# 2. Two new admins and existing accounds will use the same kubeconfig file.


# Check if at least one IP is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 node_ip [node_ip ...]"
    exit 1
fi

# Store IPs in an array
NODE_IPS=("$@")

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
for IP in "${NODE_IPS[@]}"; do
    for U in "$USER1" "$USER2"; do
        # Copy public key to remote nodes
        ssh-copy-id -i "/home/$U/.ssh/id_ed25519.pub" "$U@$IP"
    done
done

# Add admin accounts to sudoers (restricted)
echo "$USER1 ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/99-ntu-cloud
echo "$USER2 ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/99-ntu-cloud
chmod 440 /etc/sudoers.d/99-ntu-cloud

# Copy kubeconfig to the new admin accounts and existing users
for U in "$USER1" "$USER2" "lkondras" "nehalem" "JunkeMao" "yulin001"; do
  mkdir -p /home/"$U"/.kube
  cp configs/kubeconfig-admin /home/"$U"/.kube/config
  chown -R "$U":"$U" /home/"$U"/.kube
  chmod 700 /home/"$U"/.kube
  chmod 600 /home/"$U"/.kube/config
done

# Reduce access rights of all admin accounts' home directories
chmod 750 /home/"$USER1" /home/"$USER2"