#!/bin/bash

## README
# 1. For each team (1 to 5), this script creates 5 users and places them in the same group (team1, team2, etc.).
# 2. It uses the same password for all users (It's fine because we are not sahring it with participants).
# 3. Each team is mapped to its own kubeconfig file in the 'configs' directory (kubeconfig-team1, kubeconfig-team2, etc.).
# 4. The SSH keys are generated and stored locally in 'user_keys'.

# Check if password argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <password>"
    exit 1
fi

PASSWORD=$1

# Directory to store private keys
KEY_STORAGE="user_keys"
mkdir -p "$KEY_STORAGE"
chmod 700 "$KEY_STORAGE"

TEAM_COUNT=5
TEAM_USERS=("user1" "user2" "user3" "user4" "user5")

# For each team, create a group and five users
for i in $(seq 1 $TEAM_COUNT); do
    GROUP_NAME="team${i}"
    sudo groupadd -f "$GROUP_NAME"
    
    for U in "${TEAM_USERS[@]}"; do
        USERNAME="${GROUP_NAME}-${U}"

        echo "Creating user: $USERNAME"
        
        # Create user and set group
        sudo useradd -m -s /bin/bash -g "$GROUP_NAME" "$USERNAME"
        
        # Set password for the user
        echo "$USERNAME:$PASSWORD" | sudo chpasswd
        
        # Create SSH directory
        sudo mkdir -p /home/"$USERNAME"/.ssh
        sudo chmod 700 /home/"$USERNAME"/.ssh
        
        # Generate SSH key pair
        sudo -u "$USERNAME" ssh-keygen -t rsa -b 4096 -f /home/"$USERNAME"/.ssh/id_rsa -N ""
        
        # Copy the public key to authorized_keys
        sudo cp /home/"$USERNAME"/.ssh/id_rsa.pub /home/"$USERNAME"/.ssh/authorized_keys
        sudo chmod 600 /home/"$USERNAME"/.ssh/authorized_keys
        sudo chown -R "$USERNAME":"$GROUP_NAME" /home/"$USERNAME"/.ssh
        
        # Store the private key for later distribution
        sudo cp /home/"$USERNAME"/.ssh/id_rsa "$KEY_STORAGE"/"${USERNAME}_id_rsa"
        sudo chmod 600 "$KEY_STORAGE"/"${USERNAME}_id_rsa"
        
        # Distribute team-specific kubeconfig
        sudo mkdir -p /home/"$USERNAME"/.kube
        sudo cp configs/kubeconfig-"$GROUP_NAME" /home/"$USERNAME"/.kube/config
        sudo chown "$USERNAME":"$GROUP_NAME" /home/"$USERNAME"/.kube/config
        
        echo "User $USERNAME created and SSH key generated."
    done
done

##### How to use the generated keys:
# 1. Copy the private key to your local machine
# Example for team1-user1: scp team1-user1@<SERVER_IP>:~/user_keys/team1-user1_id_rsa user_keys/team1-user1_id_rsa
#
# 2. Use the private key to SSH into the remote server
# Example for team1-user1: ssh -i user_keys/team1-user1_id_rsa team1-user1@<SERVER_IP>