#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <MASTER_NODE_IP> <GRAFANA_IP>"
    echo "GRAFANA_IP: The IP address to be used by MetalLB to expose grafana service"
    exit 1
fi

# Note that the entire script is going to be executed as the root user, so all required tools need to be
# acessible to the root user (e.g., kubectl, helm, etc.)

MASTER_NODE="root@$1"
GRAFANA_IP="$2"

setup() {

    GRAFANA_IP=$1

    if ! [ -x "$(command -v kubectl)" ]; then
        echo "Error: kubectl is not installed."
        exit 1
    fi
    
    # Check if helm is installed
    if ! [ -x "$(command -v helm)" ]; then
        echo "Error: helm is not installed."
        echo "Installing helm..."
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
        apt-get install apt-transport-https --yes
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
        apt-get update --yes
        apt-get install helm --yes
    fi

    echo "Get the prometheus-stack chart"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    echo "Create a namespace for the monitoring stack"
    kubectl create namespace monitoring

    echo "Install the monitoring stack"
    RELEASE_NAME="monitoring-stack"
    helm install $RELEASE_NAME prometheus-community/kube-prometheus-stack --namespace monitoring

    echo "Check if stack is up and running"
    sleep 10s
    kubectl get pods -n monitoring

    echo "Publish grafana on a MetalLB IP"
    # User: admin Password: prom-operator
    kubectl patch svc monitoring-stack-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer", "loadBalancerIP": "'$GRAFANA_IP'"}}'
}

# SSH into the master node
ssh $MASTER_NODE << EOF
    $(typeset -f setup)
    setup $GRAFANA_IP
EOF

