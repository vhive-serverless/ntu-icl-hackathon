#! /bin/bash

ip=$(ip route | awk '/ src / {for(i=1; i<=NF; i++) if ($i == "src") print $(i+1)}' | awk '/^10\..*/ {print; exit}')

tmux new-session -d -s master
tmux send -t master "sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$ip" ENTER

until output=$(tmux capture-pane -t master -p) && echo "$output" | grep -q "kubeadm join"; do
    sleep 1
done

join_command=$(echo "$output" | grep -A 2 "kubeadm join" | tr '\n' ' ')
echo "$join_command" > /tmp/k8s_join_command

cat /tmp/k8s_join_command
    