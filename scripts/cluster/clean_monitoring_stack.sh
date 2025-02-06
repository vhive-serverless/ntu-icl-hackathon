#!/bin/bash


# Delete the helm release
helm uninstall monitoring-stack -n monitoring

# Delete the k8s namespace
kubectl delete namespace monitoring
