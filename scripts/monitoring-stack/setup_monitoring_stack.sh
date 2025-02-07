#!/bin/bash

# if [ $# -ne 1 ]; then
#     echo "Usage: $0 <GRAFANA_IP>"
#     echo "GRAFANA_IP: The IP address to be used by MetalLB to expose grafana service"
#     exit 1
# fi

# GRAFANA_IP=$1

if ! [ -x "$(command -v kubectl)" ]; then
    echo "Error: kubectl is not installed."
    exit 1
fi

# Check if helm is installed
if ! [ -x "$(command -v helm)" ]; then
    echo "Error: helm is not installed."
    echo "Installing helm..."
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update --yes
    sudo apt-get install helm --yes
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

echo "Publish grafana on the node IP"

tmux new -s grafanad -d
tmux send -t grafanad "while true; do kubectl -n monitoring port-forward deployment/monitoring-stack-grafana 3000; done" ENTER
