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

# Function to get teams from values.yaml
get_teams() {
    if [ -f "$CHART_DIR/values.yaml" ]; then
        yq e '.teams[].name' "$CHART_DIR/values.yaml"
    else
        echo "team1 team2"  # Default teams if values.yaml doesn't exist
    fi
}

# Check required tools
for tool in kubectl helm yq; do
    if ! command -v $tool &> /dev/null; then
        print_error "$tool is required but not installed. Please install $tool first."
        exit 1
    fi
done

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

# Get teams from values.yaml and create/label namespaces
print_status "Setting up team namespaces..."
for team in $(get_teams); do
    print_status "Setting up namespace for team: $team"
    kubectl create namespace "$team" --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace "$team" name="$team" access-tier=application --overwrite
done

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

# Check team namespaces
echo -e "\nTeam Namespaces:"
kubectl get namespaces -l access-tier=application

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