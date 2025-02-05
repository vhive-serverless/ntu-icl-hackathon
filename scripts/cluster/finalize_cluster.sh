#! /bin/bash

# make kubectl work for non-root

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# install calico

CALICO_VERSION=3.29.1

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v$CALICO_VERSION/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v$CALICO_VERSION/manifests/custom-resources.yaml

# install metallb

METALLB_VERSION=0.13.11

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v$METALLB_VERSION/config/manifests/metallb-native.yaml

kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

kubectl apply -f configs/metallb-pool.yaml

# install istio

ISTIO_VERSION=1.20.2

ISTIO_URL=https://github.com/istio/istio/releases/download/$ISTIO_VERSION/istio-$ISTIO_VERSION-linux-amd64.tar.gz

curl -L $ISTIO_URL -o istio.tar.gz

sudo tar -xzf istio.tar.gz -C /usr/local

/usr/local/istio-$ISTIO_VERSION/bin/istioctl install -y

# install knative

KNATIVE_VERSION=1.14.0

kubectl apply -f https://github.com/knative/serving/releases/download/knative-v$KNATIVE_VERSION/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v$KNATIVE_VERSION/serving-core.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v$KNATIVE_VERSION/serving-default-domain.yaml

kubectl wait --namespace knative-serving \
  --for=condition=ready pod \
  --selector=app=controller \
  --timeout=90s

kubectl apply -f https://github.com/knative-extensions/net-istio/releases/download/knative-v$KNATIVE_VERSION/net-istio.yaml
