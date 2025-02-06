# Quick Start Guide for MySQL and Redis Deployment

This guide helps you deploy MySQL and Redis instances in Kubernetes using Helm charts with persistent storage.

## Prerequisites

### Kubernetes Cluster Requirements
- A running Knative-enabled Kubernetes cluster with at least 3 nodes
- "standard" StorageClass must be available in the cluster
- Verify storage class availability:
  ```bash
  kubectl get storageclass standard
  ```

### Required Tools
- jq (JSON processor for command line)
- Helm v3
- Access to the Kubernetes cluster with appropriate permissions

#### Installing Prerequisites

On Ubuntu/Debian:
```bash
# Install jq
sudo apt-get install -y jq

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

On macOS:
```bash
# Using Homebrew
brew install jq
brew install helm
```

### Node Storage Setup
The following setup must be performed on ALL worker nodes in your cluster:

```bash
# Replace ${team_name} with your actual team name, e.g., "team1"
sudo mkdir -p /mnt/data/${team_name}/mysql
sudo mkdir -p /mnt/data/${team_name}/redis
sudo chmod 777 /mnt/data/${team_name}/mysql
sudo chmod 777 /mnt/data/${team_name}/redis
```

### Helm Repository Setup
```bash
# Add Bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

## File Structure
```
.
├── deploy-services.sh
└── team-values.json
```

## Configuration

Create your `team-values.json` with the following structure:
```json
{
  "team_name": "your-team-name",
  "mysql": {
    "storage_size": "8Gi",
    "root_password": "your-root-password",
    "database": "your-database",
    "username": "your-username",
    "password": "your-password",
    "resources": {
      "memory_request": "512Mi",
      "memory_limit": "1Gi",
      "cpu_request": "250m",
      "cpu_limit": "500m"
    }
  },
  "redis": {
    "storage_size": "8Gi",
    "password": "your-redis-password",
    "resources": {
      "memory_request": "256Mi",
      "memory_limit": "512Mi",
      "cpu_request": "250m",
      "cpu_limit": "500m"
    }
  }
}
```

## Deployment

1. Make the deployment script executable:
```bash
chmod +x deploy-services.sh
```

2. Run the deployment:
```bash
./deploy-services.sh team-values.json
```

The script will automatically:
- Create necessary Kubernetes resources (namespace, PV, PVC)
- Install MySQL and Redis using Helm
- Verify the deployment status

## Verification

Check the deployment status:
```bash
# Check namespace
kubectl get namespace ${team_name}

# Check PVs and PVCs
kubectl get pv
kubectl get pvc -n ${team_name}

# Check pods
kubectl get pods -n ${team_name}

# Check services
kubectl get svc -n ${team_name}
```

## Cleanup

To remove the deployment:
```bash
# Get your team name from the JSON file
TEAM_NAME=$(jq -r '.team_name' team-values.json)

# Delete Helm releases
helm uninstall ${TEAM_NAME}-mysql ${TEAM_NAME}-redis -n ${TEAM_NAME}

# Delete PVCs
kubectl delete pvc -n ${TEAM_NAME} data-${TEAM_NAME}-mysql-0 redis-data-${TEAM_NAME}-redis-master-0

# Delete PVs
kubectl delete pv mysql-pv-${TEAM_NAME} redis-pv-${TEAM_NAME}

# Delete namespace
kubectl delete namespace ${TEAM_NAME}
```

## Troubleshooting

1. Persistent Volume Issues:
   - Ensure storage directories exist on all worker nodes
   - Check directory permissions
   - Verify PV/PVC status:
     ```bash
     kubectl describe pv <pv-name>
     kubectl describe pvc <pvc-name> -n ${team_name}
     ```

2. Pod Startup Issues:
   - Check pod events:
     ```bash
     kubectl describe pod <pod-name> -n ${team_name}
     ```
   - View pod logs:
     ```bash
     kubectl logs <pod-name> -n ${team_name}
     ```

3. Node Affinity Issues:
   - Verify node labels:
     ```bash
     kubectl get nodes --show-labels
     ```
   - Ensure you have enough worker nodes (non-control-plane nodes)

## Security Notes

- Update default passwords in `team-values.json`
- Consider using Kubernetes Secrets for sensitive data
- Review and adjust directory permissions based on your security requirements
- In production, consider implementing network policies

## Support

For issues and questions:
- Check pod logs: `kubectl logs <pod-name> -n ${team_name}`
- Check events: `kubectl get events -n ${team_name}`
- Review Helm release status: `helm list -n ${team_name}`
- Ensure all worker nodes have the required directories and permissions
- Verify cluster has minimum 3 nodes as required