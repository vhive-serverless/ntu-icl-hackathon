#!/bin/bash

# README:
# 1. This script assumes the existence of 'kubeconfig-admin' file in the 'configs' directory.
# 2. Two new admins and existing accounds will use the same kubeconfig file.
# 3. The script uses keys generated by 'create_admins_key.sh' script.

# Create ntu-cloud group if it doesn't exist
sudo groupadd -f ntu-cloud

# Two new admin accounts
USER1="admin_user1"
USER2="admin_user2"

# Create users and add them to ntu-cloud group
# sudo useradd -m -s /bin/bash -g ntu-cloud "$USER1"
# sudo useradd -m -s /bin/bash -g ntu-cloud "$USER2"

# (Optional) Set passwords for these new accounts
# passwd "$USER1"
# passwd "$USER2"

# Use keys generated by create_admins_key.sh instead of creating new ones
for U in "$USER1" "$USER2"; do
    sudo useradd -m -s /bin/bash -g ntu-cloud "$U"
    sudo adduser "$U" sudo

    sudo mkdir -p /home/"$U"/.ssh
    sudo cp admin_keys/"${U}_key.pub" /home/"$U"/.ssh/authorized_keys
    # Set proper permissions
    sudo chown -R "$U":ntu-cloud /home/"$U"/.ssh
    sudo chmod 700 /home/"$U"/.ssh
    sudo chmod 600 /home/"$U"/.ssh/authorized_keys

    # Grant NOPASSWD sudo access for admin users
    echo "$U ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/"$U"
    sudo chmod 440 /etc/sudoers.d/"$U"

    sudo mkdir -p /home/"$U"/.kube
    sudo cp configs/kubeconfig-admin /home/"$U"/.kube/config
    sudo chown -R "$U":ntu-cloud /home/"$U"/.kube
    sudo chmod 700 /home/"$U"/.kube
    sudo chmod 600 /home/"$U"/.kube/config
    sudo chmod 750 /home/"$U"
done

# sudo chmod 440 /etc/sudoers.d/99-ntu-cloud

# Copy kubeconfig to the new admin accounts and existing users
for U in "lkondras" "nehalem" "Junkemao" "yulin001"; do
    sudo mkdir -p /users/"$U"/.kube
    sudo cp configs/kubeconfig-admin /users/"$U"/.kube/config
    sudo chown -R "$U":ntu-cloud /users/"$U"/.kube
    sudo chmod 700 /users/"$U"/.kube
    sudo chmod 600 /users/"$U"/.kube/config
    sudo chmod 750 /users/"$U"
done
