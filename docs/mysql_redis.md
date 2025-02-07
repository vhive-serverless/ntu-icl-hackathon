# MySQL and Redis Deployment

This script employs a Helm chart to deploy MySQL and Redis services in a Kubernetes cluster. Each team gets their own isolated Redis instance and database in MySQL with proper resource limits and access controls.

## Prerequisites

- Kubernetes cluster with at least 2 worker nodes
- kubectl

## Directory Structure

``` tree
.
├── deploy-shared-services.sh
└── shared-db-services/
    ├── Chart.yaml
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

The script will prompt you for the number of teams to deploy. It will generate a values.yaml file with the specified number of teams. The max number of teams is 5. The credentials are generated in a `credentials-<timestamp>.txt` file.

To edit the limits and requests of the databases, please refer to the `Global MySQL configuration` and `Global Redis configuration` sections in the `deploy-shared-services.sh` script. 

### MySQL Requirements per Instance

- **CPU Limits:** 4 cores
- **CPU Requests:** 2 cores  
- **Memory Limits:** 8Gi
- **Memory Requests:** 4Gi
- **Storage:** 100Gi

### Redis Requirements per Team

- **CPU Limits:** 500m (0.5 cores)
- **CPU Requests:** 250m (0.25 cores)
- **Memory Limits:** 1Gi
- **Memory Requests:** 512Mi
- **Storage:** 10Gi

## Deployment

1. Make the deployment script executable:

```bash
chmod +x deploy-shared-services.sh
```

2. Run the deployment:

```bash
./deploy-shared-services.sh <number_of_teams>
```

## Testing the Deployment

1. Create a test pod:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-test-pod
spec:
  containers:
  - name: mysql-redis-client
    image: ubuntu:22.04
    command: ['sleep', '3600']
EOF

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/db-test-pod
```

2. Install test tools:

```bash
kubectl exec -it db-test-pod -- bash -c 'apt-get update && apt-get install -y mysql-client redis-tools'
```

3. Test MySQL:

```bash
# Test connection
kubectl exec -it db-test-pod -- mysql -h mysql.shared-services.svc.cluster.local \
  -u team1_user -p'team1_mysql_pass' \
  -e "SHOW DATABASES;"

# Create and query a table
kubectl exec -it db-test-pod -- mysql -h mysql.shared-services.svc.cluster.local \
  -u team1_user -p'team1_mysql_pass' team1_db \
  -e "CREATE TABLE test (id INT, name VARCHAR(50));
      INSERT INTO test VALUES (1, 'test1');
      SELECT * FROM test;"
```

4. Test Redis:

```bash
# Set and get a key
kubectl exec -it db-test-pod -- redis-cli \
  -h redis-team1.shared-services.svc.cluster.local \
  -a 'team1_redis_pass' \
  SET test_key "Hello from team1"

kubectl exec -it db-test-pod -- redis-cli \
  -h redis-team1.shared-services.svc.cluster.local \
  -a 'team1_redis_pass' \
  GET test_key
```

### Kubernetes Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
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

# Delete StorageClass
kubectl delete storageclass standard

# Delete PVs
kubectl delete pv mysql-pv
kubectl delete pv redis-pv-team<number_of_teams>

# Clean up storage on worker nodes
kubectl debug node/<node-name> -it --image=busybox -- chroot /host sh -c "rm -rf /mnt/data"
```
