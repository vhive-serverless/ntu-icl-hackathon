# Cluster Creation

How to create a cluster for the hackathon.

## CloudLab

Create a new experiment with `ntu-cloud/vhive-ubuntu20` profile

## Local

Run on local machine:

```bash
./scripts/cluster/deploy_k8s.sh <master-node> <node1> <node2> ...
```

## Done!

This installs k8s and knative on the nodes.

You can check the cluster status from master node with:

```bash
kubectl get nodes
```
