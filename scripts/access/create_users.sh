#!/bin/bash

## README
# 1. The assumption here is that every team can have access to just one node (if this is not the case, please tell me)
# 2. This script uses the same password for all users (but since they are part of the same team it should be fine)
# 3. When you want to run this script for different teams, you should provide a different password!
# 4. I have included a section at the end of the script on how to use the generated keys


# Check if password argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <password>"
    exit 1
fi

PASSWORD=$1

# List of users to be created
USERS=("user1" "user2" "user3" "user4" "user5")

# Directory to store private keys (optional)
KEY_STORAGE="user_keys"
mkdir -p $KEY_STORAGE
chmod 700 $KEY_STORAGE

for USER in "${USERS[@]}"; do
    echo "Creating user: $USER"

    # Create user without sudo privileges
    sudo useradd -m -s /bin/bash "$USER"

    # Set the password (all users will have the same password)
    echo "$USER:$PASSWORD" | sudo chpasswd

    # Create SSH directory
    sudo mkdir -p /home/$USER/.ssh
    sudo chmod 700 /home/$USER/.ssh

    # Generate SSH key pair
    sudo -u $USER ssh-keygen -t rsa -b 4096 -f /home/$USER/.ssh/id_rsa -N ""

    # Copy the public key to authorized_keys for SSH access
    sudo cp /home/$USER/.ssh/id_rsa.pub /home/$USER/.ssh/authorized_keys
    sudo chmod 600 /home/$USER/.ssh/authorized_keys
    sudo chown -R $USER:$USER /home/$USER/.ssh

    # Store the private key in root directory for later distribution
    sudo cp /home/$USER/.ssh/id_rsa $KEY_STORAGE/${USER}_id_rsa
    sudo chmod 600 $KEY_STORAGE/${USER}_id_rsa

    echo "User $USER created and SSH key generated."

    # distribute kubeconfigs
    # sudo mkdir -p /home/$USER/.kube
    # sudo cp configs/kubeconfig-$TEAM /home/$USER/.kube/config
    # sudo chown $USER:$USER /home/$USER/.kube/config
done

##### How to use the generated keys:
# 1. Copy the private key to your local machine
# Example for user1: scp user1@<SERVER_IP>:~/user_keys/user1_id_rsa user_keys/user1_id_rsa

# 2. Use the private key to SSH into the remote server
# Example for user1: ssh -i user_keys/user1_id_rsa user1@<SERVER_IP>