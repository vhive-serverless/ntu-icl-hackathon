#!/bin/bash
kn service delete --all -n example 1>/dev/null 2>&1
kubectl delete namespace example 1>/dev/null 2>&1
kubectl create namespace example

kn service apply -f producer/producer.yaml -n example
kn service apply -f consumer/consumer.yaml -n example