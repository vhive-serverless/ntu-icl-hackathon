kn service delete --all -n example 1>/dev/null 2>&1
kubectl delete namespace example 1>/dev/null 2>&1
kubectl create namespace example

kubectl apply -f example/kubernetes/yamls/pv.yaml
kubectl apply -f example/kubernetes/yamls/pvc.yaml

