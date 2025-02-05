#! /bin/bash

ip=$(ip route | awk '/ src / {for(i=1; i<=NF; i++) if ($i == "src") print $(i+1)}' | awk '/^10\..*/ {print; exit}')

join_command=$(sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$ip | tail -n 2 | tr '\\\n' ' ')

echo "$join_command"
    