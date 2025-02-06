#!/bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    exit 1
fi

# Function to replace placeholders in a template
replace_placeholders() {
    local template=$1
    local json_file=$2
    
    # Get team name
    local team_name=$(jq -r '.team_name' "$json_file")
    template=${template//\$\{team_name\}/$team_name}
    
    # Replace MySQL values
    template=${template//\$\{mysql.storage_size\}/$(jq -r '.mysql.storage_size' "$json_file")}
    template=${template//\$\{mysql.root_password\}/$(jq -r '.mysql.root_password' "$json_file")}
    template=${template//\$\{mysql.database\}/$(jq -r '.mysql.database' "$json_file")}
    template=${template//\$\{mysql.username\}/$(jq -r '.mysql.username' "$json_file")}
    template=${template//\$\{mysql.password\}/$(jq -r '.mysql.password' "$json_file")}
    template=${template//\$\{mysql.resources.memory_request\}/$(jq -r '.mysql.resources.memory_request' "$json_file")}
    template=${template//\$\{mysql.resources.memory_limit\}/$(jq -r '.mysql.resources.memory_limit' "$json_file")}
    template=${template//\$\{mysql.resources.cpu_request\}/$(jq -r '.mysql.resources.cpu_request' "$json_file")}
    template=${template//\$\{mysql.resources.cpu_limit\}/$(jq -r '.mysql.resources.cpu_limit' "$json_file")}
    
    # Replace Redis values
    template=${template//\$\{redis.storage_size\}/$(jq -r '.redis.storage_size' "$json_file")}
    template=${template//\$\{redis.password\}/$(jq -r '.redis.password' "$json_file")}
    template=${template//\$\{redis.resources.memory_request\}/$(jq -r '.redis.resources.memory_request' "$json_file")}
    template=${template//\$\{redis.resources.memory_limit\}/$(jq -r '.redis.resources.memory_limit' "$json_file")}
    template=${template//\$\{redis.resources.cpu_request\}/$(jq -r '.redis.resources.cpu_request' "$json_file")}
    template=${template//\$\{redis.resources.cpu_limit\}/$(jq -r '.redis.resources.cpu_limit' "$json_file")}
    
    echo "$template"
}

# Template definitions
read -r -d '' MYSQL_PV_TEMPLATE << 'EOF'
# mysql-pv-template.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv-${team_name}
spec:
  capacity:
    storage: ${mysql.storage_size}
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /mnt/data/${team_name}/mysql
    type: DirectoryOrCreate
  claimRef:
    namespace: ${team_name}
    name: data-${team_name}-mysql-0
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/control-plane
          operator: DoesNotExist
EOF

read -r -d '' MYSQL_PVC_TEMPLATE << 'EOF'
# mysql-pvc-template.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-${team_name}-mysql-0
  namespace: ${team_name}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${mysql.storage_size}
  storageClassName: standard
EOF

read -r -d '' MYSQL_VALUES_TEMPLATE << 'EOF'
# mysql-values-template.yaml
auth:
  rootPassword: ${mysql.root_password}
  database: ${mysql.database}
  username: ${mysql.username}
  password: ${mysql.password}
  existingSecret: ""

primary:
  persistence:
    storageClass: "standard"
    size: ${mysql.storage_size}
  configuration: |
    [mysqld]
    character-set-server=utf8mb4
    collation-server=utf8mb4_unicode_ci
    socket=/opt/bitnami/mysql/tmp/mysql.sock
    pid-file=/opt/bitnami/mysql/tmp/mysqld.pid

    [client]
    socket=/opt/bitnami/mysql/tmp/mysql.sock

    [mysql]
    socket=/opt/bitnami/mysql/tmp/mysql.sock

    [mysqladmin]
    socket=/opt/bitnami/mysql/tmp/mysql.sock

  extraVolumeMounts:
    - name: tmp-volume
      mountPath: /opt/bitnami/mysql/tmp-custom

  extraVolumes:
    - name: tmp-volume
      emptyDir: {}
    
resources:
  requests:
    memory: ${mysql.resources.memory_request}
    cpu: ${mysql.resources.cpu_request}
  limits:
    memory: ${mysql.resources.memory_limit}
    cpu: ${mysql.resources.cpu_limit}

networkPolicy:
  enabled: false
EOF

read -r -d '' REDIS_PV_TEMPLATE << 'EOF'
# redis-pv-template.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis-pv-${team_name}
spec:
  capacity:
    storage: ${redis.storage_size}
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /mnt/data/${team_name}/redis
    type: DirectoryOrCreate
  claimRef:
    namespace: ${team_name}
    name: redis-data-${team_name}-redis-master-0
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/control-plane
          operator: DoesNotExist
EOF

read -r -d '' REDIS_PVC_TEMPLATE << 'EOF'
# redis-pvc-template.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data-${team_name}-redis-master-0
  namespace: ${team_name}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${redis.storage_size}
  storageClassName: standard
EOF

read -r -d '' REDIS_VALUES_TEMPLATE << 'EOF'
# redis-values-template.yaml
auth:
  password: ${redis.password}
  existingSecret: ""

master:
  persistence:
    enabled: true
    storageClass: "standard"
    size: ${redis.storage_size}
    existingClaim: redis-data-${team_name}-redis-master-0
  extraVolumeMounts:
    - name: tmp-volume
      mountPath: /opt/bitnami/redis/tmp-custom
  extraVolumes:
    - name: tmp-volume
      emptyDir: {}
  resources:
    requests:
      memory: ${redis.resources.memory_request}
      cpu: ${redis.resources.cpu_request}
    limits:
      memory: ${redis.resources.memory_limit}
      cpu: ${redis.resources.cpu_limit}

replica:
  replicaCount: 0

architecture: standalone
networkPolicy:
  enabled: false
EOF

# Check required argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <json_values_file>"
    exit 1
fi

JSON_VALUES=$1

# Check if file exists
if [ ! -f "$JSON_VALUES" ]; then
    echo "Error: File $JSON_VALUES does not exist"
    exit 1
fi

# Get team name from JSON
TEAM_NAME=$(jq -r '.team_name' "$JSON_VALUES")

echo "Starting deployment for team: $TEAM_NAME"

# Create temporary directory for generated files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Generate configuration files
echo "Generating configuration files..."
echo "$(replace_placeholders "$MYSQL_PV_TEMPLATE" "$JSON_VALUES")" > "$TEMP_DIR/mysql-pv.yaml"
echo "$(replace_placeholders "$MYSQL_PVC_TEMPLATE" "$JSON_VALUES")" > "$TEMP_DIR/mysql-pvc.yaml"
echo "$(replace_placeholders "$MYSQL_VALUES_TEMPLATE" "$JSON_VALUES")" > "$TEMP_DIR/mysql-values.yaml"
echo "$(replace_placeholders "$REDIS_PV_TEMPLATE" "$JSON_VALUES")" > "$TEMP_DIR/redis-pv.yaml"
echo "$(replace_placeholders "$REDIS_PVC_TEMPLATE" "$JSON_VALUES")" > "$TEMP_DIR/redis-pvc.yaml"
echo "$(replace_placeholders "$REDIS_VALUES_TEMPLATE" "$JSON_VALUES")" > "$TEMP_DIR/redis-values.yaml"

# Follow the deployment sequence
echo "Creating namespace: $TEAM_NAME"
kubectl create namespace "$TEAM_NAME"

echo "Applying MySQL PV..."
kubectl apply -f "$TEMP_DIR/mysql-pv.yaml"

echo "Applying Redis PV..."
kubectl apply -f "$TEMP_DIR/redis-pv.yaml"

echo "Applying MySQL PVC..."
kubectl apply -f "$TEMP_DIR/mysql-pvc.yaml"

echo "Applying Redis PVC..."
kubectl apply -f "$TEMP_DIR/redis-pvc.yaml"

echo "Verifying PV and PVC status..."
kubectl get pv
kubectl get pvc -n "$TEAM_NAME"

# Add Bitnami repo if not already added
echo "Ensuring Bitnami repo is added..."
helm repo list | grep -q "bitnami" || helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

echo "Installing MySQL..."
helm install "$TEAM_NAME-mysql" bitnami/mysql \
    -f "$TEMP_DIR/mysql-values.yaml" \
    --namespace "$TEAM_NAME"

echo "Installing Redis..."
helm install "$TEAM_NAME-redis" bitnami/redis \
    -f "$TEMP_DIR/redis-values.yaml" \
    --namespace "$TEAM_NAME"

echo "Deployment completed. Checking status..."
kubectl get pods -n "$TEAM_NAME"

echo "Deployment process completed!"
