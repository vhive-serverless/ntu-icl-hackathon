#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CHART_DIR="${SCRIPT_DIR}/shared-db-services"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to show usage information
show_usage() {
    echo "Usage: $0 [number_of_teams]"
    echo "  number_of_teams: Optional. Number of teams to configure (1-5). Default is 2."
    echo "Example: $0 3"
}

# Function to generate random password
generate_password() {
    # Generate a 16-character random password with letters and numbers
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12
}

# Function to generate values.yaml content
generate_values_yaml() {
    local num_teams=$1
    local values_file="${CHART_DIR}/values.yaml"
    
    # Create base values.yaml content
    cat > "$values_file" << EOF
# values.yaml
namespace: shared-services

# Team configurations - automatically generated
teams:
EOF

    # Generate team configurations
    for ((i=1; i<=num_teams; i++)); do
        local mysql_pass=$(generate_password)
        local redis_pass=$(generate_password)
        
        cat >> "$values_file" << EOF
  - name: team${i}
    mysql:
      database: team${i}_db
      username: team${i}_user
      password: ${mysql_pass}
    redis:
      password: ${redis_pass}
EOF
    done

    # Add global configurations
    cat >> "$values_file" << EOF

# Global MySQL configuration
mysql:
  rootPassword: $(generate_password)
  image: mysql:8.0
  resources:
    limits:
      cpu: "4"
      memory: "8Gi"
    requests:
      cpu: "2"
      memory: "4Gi"
  storage:
    size: 100Gi
  global:
    maxConnections: 1000
    maxUserConnections: 50
    queriesPerHour: 10000
    updatesPerHour: 5000
    connectionsPerHour: 1000

# Global Redis configuration
redis:
  image: redis:7.0
  resources:
    limits:
      cpu: "500m"
      memory: "1Gi"
    requests:
      cpu: "250m"
      memory: "512Mi"
  storage:
    size: 10Gi
  global:
    maxMemory: "1gb"
    maxClients: 1000
EOF

    print_status "Generated values.yaml with ${num_teams} team(s)"
    
    # Create a backup of credentials
    local creds_file="${SCRIPT_DIR}/credentials-$(date +%Y%m%d-%H%M%S).txt"
    print_status "Saving credentials to ${creds_file}"
    
    echo "Database Credentials (Generated on $(date))" > "$creds_file"
    echo "==========================================" >> "$creds_file"
    echo "" >> "$creds_file"
    echo "MySQL Root Password: $(yq e '.mysql.rootPassword' "$values_file")" >> "$creds_file"
    echo "" >> "$creds_file"
    
    for ((i=1; i<=num_teams; i++)); do
        echo "Team${i} Credentials:" >> "$creds_file"
        echo "-------------------" >> "$creds_file"
        echo "MySQL:" >> "$creds_file"
        echo "  Database: team${i}_db" >> "$creds_file"
        echo "  Username: team${i}_user" >> "$creds_file"
        echo "  Password: $(yq e ".teams[] | select(.name == \"team${i}\") | .mysql.password" "$values_file")" >> "$creds_file"
        echo "Redis:" >> "$creds_file"
        echo "  Password: $(yq e ".teams[] | select(.name == \"team${i}\") | .redis.password" "$values_file")" >> "$creds_file"
        echo "" >> "$creds_file"
    done
    
    chmod 600 "$creds_file"
}

# Parse command line arguments
NUM_TEAMS=2  # Default value
if [ $# -gt 0 ]; then
    if [[ "$1" =~ ^[1-5]$ ]]; then
        NUM_TEAMS=$1
    else
        print_error "Number of teams must be between 1 and 5"
        show_usage
        exit 1
    fi
fi

# Generate values.yaml with specified number of teams
generate_values_yaml $NUM_TEAMS

# Function to get teams (modified to use values.yaml if it exists)
get_teams() {
    if [ -f "$CHART_DIR/values.yaml" ]; then
        yq e '.teams[].name' "$CHART_DIR/values.yaml"
    else
        seq -f "team%g" 1 $NUM_TEAMS
    fi
}

# Check and install required tools
if ! [ -x "$(command -v helm)" ]; then
    echo "Error: helm is not installed."
    echo "Installing helm..."
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update --yes
    sudo apt-get install helm --yes
fi

if ! command -v yq &> /dev/null; then
    print_status "Installing yq..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod a+x /usr/local/bin/yq
fi

# Verify chart directory exists
if [ ! -d "$CHART_DIR" ]; then
    print_error "Chart directory not found at $CHART_DIR"
    echo "Expected directory structure:"
    echo "."
    echo "├── deploy-shared-services.sh"
    echo "└── shared-db-services/"
    echo "    ├── Chart.yaml"
    echo "    ├── values.yaml"
    echo "    └── templates/"
    exit 1
fi

print_status "Starting deployment process..."

# Add Bitnami repo if not already added
if ! helm repo list | grep -q "bitnami"; then
    print_status "Adding Bitnami Helm repository..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
else
    print_status "Bitnami repo already added, updating..."
    helm repo update
fi

# Clean up existing resources
if helm list -n shared-services 2>/dev/null | grep -q "shared-db-services"; then
    print_warning "Found existing Helm release. This will be purged."
    helm uninstall shared-db-services -n shared-services
    sleep 5
fi

# Remove namespace if it exists
if kubectl get namespace shared-services &>/dev/null; then
    print_warning "Found existing shared-services namespace. Deleting it to ensure clean state..."
    print_warning "This will delete all resources in the namespace!"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace shared-services
        while kubectl get namespace shared-services &>/dev/null; do
            print_status "Waiting for namespace deletion..."
            sleep 5
        done
        # Additional wait to ensure cleanup
        sleep 10
    else
        print_error "Deployment cancelled by user"
        exit 1
    fi
fi

# Create namespace with required labels
print_status "Creating namespace with Helm labels..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: shared-services
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: shared-db-services
    meta.helm.sh/release-namespace: shared-services
EOF

# Wait for namespace to be fully created
sleep 5

# Function to setup storage directories on nodes
setup_storage() {
    print_status "Setting up storage directories on worker nodes..."
    
    # Get all worker nodes
    WORKER_NODES=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')
    
    for node in $WORKER_NODES; do
        print_status "Setting up storage on node: $node"
        
        # Create MySQL directory
        kubectl debug node/$node -it --image=busybox -- chroot /host sh -c \
            "mkdir -p /mnt/data/mysql && chmod 777 /mnt/data/mysql"
        
        # Create Redis directories for each team
        for team in $(get_teams); do
            kubectl debug node/$node -it --image=busybox -- chroot /host sh -c \
                "mkdir -p /mnt/data/$team/redis && chmod 777 /mnt/data/$team/redis"
        done
    done
}

# Setup storage directories
print_status "Setting up storage..."
setup_storage

# Create StorageClass if it doesn't exist
if ! kubectl get storageclass standard &>/dev/null; then
    print_status "Creating standard StorageClass..."
    kubectl apply -f "$CHART_DIR/templates/storage/storageclass.yaml"
fi

# Deploy the Helm chart
print_status "Deploying shared database services..."
helm upgrade --install shared-db-services "$CHART_DIR" \
    --namespace shared-services \
    --wait \
    --timeout 10m || {
        print_error "Helm deployment failed"
        exit 1
    }

# Deploy the Helm chart without namespace creation
print_status "Deploying shared database services..."
helm upgrade --install shared-db-services "$CHART_DIR" \
    --namespace shared-services \
    --wait \
    --timeout 10m || {
        print_error "Helm deployment failed"
        exit 1
    }

print_status "Verifying deployment status..."

# Check pod status
echo "Pod Status:"
kubectl get pods -n shared-services

# Check PVC status
echo -e "\nPersistent Volume Claims:"
kubectl get pvc -n shared-services

# Check service status
echo -e "\nServices:"
kubectl get svc -n shared-services

print_status "Deployment process completed!"

# Print connection information
print_status "Connection Information:"
echo "MySQL:"
echo "  Host: mysql.shared-services.svc.cluster.local"
echo "  Port: 3306"
echo "Redis:"
for team in $(get_teams); do
    echo "  Team: $team"
    echo "    Host: redis-${team}.shared-services.svc.cluster.local"
    echo "    Port: 6379"
done