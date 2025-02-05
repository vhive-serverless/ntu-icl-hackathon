#! /bin/bash

tmux send -t master "y" ENTER

# install calico

CALICO_VERSION=3.29.1

sudo kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v$CALICO_VERSION/manifests/calico.yaml
# install metallb

METALLB_VERSION=0.13.11

sudo kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v$METALLB_VERSION/config/manifests/metallb-native.yaml

# install istio

ISTIO_VERSION=1.20.0

sudo kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-$ISTIO_VERSION/manifests/charts/base/crds.yaml

# install knative

KNATIVE_VERSION=1.14.0

sudo kubectl apply -f https://github.com/knative/serving/releases/download/knative-v$KNATIVE_VERSION/serving-crds.yaml
sudo kubectl apply -f https://github.com/knative/serving/releases/download/knative-v$KNATIVE_VERSION/serving-core.yaml
sudo kubectl apply -f https://github.com/knative/serving/releases/download/knative-v$KNATIVE_VERSION/serving-default-domain.yaml
sudo kubectl apply -f https://github.com/knative-extensions/net-istio/releases/download/knative-v$KNATIVE_VERSION/net-istio.yaml
