#!/bin/bash


if [ $# -ne 1 ]; then
    echo "Usage: $0 <MASTER_NODE_IP>"
    exit 1
fi

# Note that the entire script is going to be executed as the root user, so all required tools need to be
# acessible to the root user (e.g., kubectl, helm, etc.)

MASTER_NODE="root@$1"

ssh $MASTER_NODE << EOF
    # Delete the helm release
    helm uninstall monitoring-stack -n monitoring

    # Delete the k8s namespace
    kubectl delete namespace monitoring
EOF
