#!/bin/bash

# Disable swap

sudo swapoff -a && sudo cp /etc/fstab /etc/fstab.old
sudo sed -i 's/#\\s*\\(.*swap.*\\)/\\1/g' /etc/fstab && sudo sed -i 's/.*swap.*/# &/g' /etc/fstab

# configure network

sudo modprobe br_netfilter && sudo modprobe overlay
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

#install go

GO_VERSION=1.23.5

wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz

sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz

export PATH=$PATH:/usr/local/go/bin
cat <<EOF | sudo tee /etc/profile.d/go.sh
export PATH=\$PATH:/usr/local/go/bin
EOF

# Install containerd

sudo sysctl --system

CTRD_VERSION=1.7.1

wget https://github.com/containerd/containerd/releases/download/v$CTRD_VERSION/containerd-$CTRD_VERSION-linux-amd64.tar.gz

sudo tar Cxzvf /usr/local containerd-$CTRD_VERSION-linux-amd64.tar.gz

sudo mkdir -p /etc/containerd

cat <<EOF | sudo tee /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.9"
EOF

sudo systemctl enable --now containerd

# Install runc

RUNC_VERSION=1.1.10

wget https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/runc.amd64

sudo install -m 755 runc.amd64 /usr/local/bin/runc

# Install CNI

CNI_VERSION=1.4.0

wget https://github.com/containernetworking/plugins/releases/download/v$CNI_VERSION/cni-plugins-linux-amd64-v$CNI_VERSION.tgz

sudo mkdir -p /opt/cni/bin

sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v$CNI_VERSION.tgz

# Install kubeadm, kubelet, and kubectl

K8S_VERSION=1.29

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Install kn

KN_VERSION=1.14
git clone https://github.com/knative/client.git --branch release-$KN_VERSION --depth 1
pushd client
hack/build.sh -f
sudo mv kn /usr/local/bin
popd

# Add the Kubernetes signing key

sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes repository

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubelet, and kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# install kn

# KN_VERSION=1.14.0



# Set node IP for kubelet

ip=$(ip route | awk '/ src / {for(i=1; i<=NF; i++) if ($i == "src") print $(i+1)}' | awk '/^10\..*/ {print; exit}')
echo "KUBELET_EXTRA_ARGS=--node-ip=$ip" | sudo tee /etc/default/kubelet

sudo systemctl enable --now kubelet

# run containerd

sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service
tmux new -s containerd -d
tmux send -t containerd "sudo systemctl enable --now containerd" ENTER
