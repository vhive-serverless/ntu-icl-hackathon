# MySQL and Redis Deployment

This script employs a Helm chart to deploy MySQL and Redis services in a Kubernetes cluster. Each team gets their own isolated Redis instance and database in MySQL with proper resource limits and access controls.

## Prerequisites

- Kubernetes cluster with at least 2 worker nodes
- Helm v3
- kubectl
- yq

> **_NOTE:_**
> The scripts should be executed on the Kubernetes control-plane node.

### Installing Prerequisites

On Ubuntu/Debian:
```bash
# Install required tools
sudo apt-get update
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod a+x /usr/local/bin/yq

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

## Directory Structure

The deployment scripts and configuration files are located in `scripts/mysql-redis/`:

```
.
├── deploy-shared-services.sh
└── shared-db-services/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── namespace.yaml
        ├── mysql/
        │   ├── configmap.yaml
        │   ├── service.yaml
        │   ├── statefulset.yaml
        │   ├── secrets.yaml
        │   └── networkpolicy.yaml
        ├── redis/
        │   ├── instances.yaml
        │   └── secrets.yaml
        ├── storage/
        │   ├── storageclass.yaml
        │   └── volumes.yaml
        └── _helpers.tpl
```

## Configuration

Edit `values.yaml` to configure teams and resources:

```yaml
namespace: shared-services

teams:
  - name: team1
    mysql:
      database: team1_db
      username: team1_user
      password: team1_mysql_pass
    redis:
      password: team1_redis_pass
  - name: team2
    mysql:
      database: team2_db
      username: team2_user
      password: team2_mysql_pass
    redis:
      password: team2_redis_pass
  # Add more teams as needed

mysql:
  rootPassword: root_password
  resources:
    limits:
      cpu: "4"
      memory: "8Gi"
    requests:
      cpu: "2"
      memory: "4Gi"

redis:
  resources:
    limits:
      cpu: "500m"
      memory: "1Gi"
    requests:
      cpu: "250m"
      memory: "512Mi"
```

## Deployment

1. Make the deployment script executable:
```bash
chmod +x deploy-shared-services.sh
```

2. Run the deployment:
```bash
./deploy-shared-services.sh
```

## Testing the Deployment

1. Create a test pod:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-test-pod
  namespace: team1
spec:
  containers:
  - name: mysql-redis-client
    image: ubuntu:22.04
    command: ['sleep', '3600']
EOF

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/db-test-pod -n team1
```

2. Install test tools:
```bash
kubectl exec -it db-test-pod -n team1 -- bash -c 'apt-get update && apt-get install -y mysql-client redis-tools'
```

3. Test MySQL:
```bash
# Test connection
kubectl exec -it db-test-pod -n team1 -- mysql -h mysql.shared-services.svc.cluster.local \
  -u team1_user -p'team1_mysql_pass' \
  -e "SHOW DATABASES;"

# Create and query a table
kubectl exec -it db-test-pod -n team1 -- mysql -h mysql.shared-services.svc.cluster.local \
  -u team1_user -p'team1_mysql_pass' team1_db \
  -e "CREATE TABLE test (id INT, name VARCHAR(50));
      INSERT INTO test VALUES (1, 'test1');
      SELECT * FROM test;"
```

4. Test Redis:
```bash
# Set and get a key
kubectl exec -it db-test-pod -n team1 -- redis-cli \
  -h redis-team1.shared-services.svc.cluster.local \
  -a 'team1_redis_pass' \
  SET test_key "Hello from team1"

kubectl exec -it db-test-pod -n team1 -- redis-cli \
  -h redis-team1.shared-services.svc.cluster.local \
  -a 'team1_redis_pass' \
  GET test_key
```

## Using in Python Applications

### MySQL Example

```python
from mysql.connector import connect

def get_mysql_connection():
    return connect(
        host="mysql.shared-services.svc.cluster.local",
        user="team1_user",
        password="team1_mysql_pass",
        database="team1_db"
    )

# Usage example
with get_mysql_connection() as conn:
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users")
    results = cursor.fetchall()
```

### Redis Example

```python
from redis import Redis

def get_redis_connection():
    return Redis(
        host="redis-team1.shared-services.svc.cluster.local",
        port=6379,
        password="team1_redis_pass",
        decode_responses=True
    )

# Usage example
redis_client = get_redis_connection()
redis_client.set("user:123", "John Doe")
user = redis_client.get("user:123")
```

### Kubernetes Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: team1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: my-app:latest
        env:
        - name: MYSQL_HOST
          value: "mysql.shared-services.svc.cluster.local"
        - name: MYSQL_USER
          value: "team1_user"
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-credentials
              key: password
        - name: REDIS_HOST
          value: "redis-team1.shared-services.svc.cluster.local"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: password
```

## Cleanup

To remove the deployment:

```bash
# Delete Helm release
helm uninstall shared-db-services -n shared-services

# Delete namespaces
kubectl delete namespace shared-services
kubectl delete namespace team1
kubectl delete namespace team2

# Delete StorageClass
kubectl delete storageclass standard

# Delete PVs
kubectl delete pv mysql-pv
kubectl delete pv redis-pv-team1
kubectl delete pv redis-pv-team2

# Clean up storage on worker nodes
kubectl debug node/<node-name> -it --image=busybox -- chroot /host sh -c "rm -rf /mnt/data"
```

## Resource Limits

- Each MySQL instance:
  - CPU: 4 cores limit, 2 cores request
  - Memory: 8Gi limit, 4Gi request
  - Storage: Defined in values.yaml

- Each Redis instance:
  - CPU: 500m limit, 250m request
  - Memory: 1Gi limit, 512Mi request
  - Storage: Defined in values.yaml

## Security Notes

1. Store sensitive information (passwords, etc.) in Kubernetes secrets
2. Use network policies to restrict access
3. Regularly update passwords
4. Monitor resource usage
5. Keep the services up to date

## Troubleshooting

1. Check pod status:
```bash
kubectl get pods -n shared-services
```

2. View pod logs:
```bash
kubectl logs <pod-name> -n shared-services
```

3. Check PVC status:
```bash
kubectl get pvc -n shared-services
```

4. Verify network policies:
```bash
kubectl get networkpolicies -n shared-services
```
