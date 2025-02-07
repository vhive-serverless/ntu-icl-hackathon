#!/bin/bash

run_on_node() {
    ssh -oStrictHostKeyChecking=no -p 22 "$1" "$2";
}

# clone repo and setup node on all nodes

setup_node() {
    rsync -avzh --progress --stats ../ntu-icl-hackathon $1:~
    # run_on_node $1 "git clone https://github.com/ntu-icl-hackathon/ntu-icl-hackathon.git"
    run_on_node $1 "cd ntu-icl-hackathon && ./scripts/cluster/setup_node.sh"
}

for node in $@; do
    setup_node $node &
done

wait

# create cluster

MASTER_NODE=$1
shift

join_command=$(run_on_node $MASTER_NODE "cd ntu-icl-hackathon && ./scripts/cluster/init_cluster.sh")

# join nodes to cluster

for node in $@; do
    run_on_node $node "sudo $join_command" &
done

wait

# finalize master

run_on_node $MASTER_NODE "cd ntu-icl-hackathon && ./scripts/cluster/finalize_cluster.sh"
run_on_node $MASTER_NODE "cd ntu-icl-hackathon && ./scripts/cluster/post_deployment.sh"

# access management

run_on_node $MASTER_NODE "cd ntu-icl-hackathon && ./scripts/access/generate_kubeconfigs.sh"
rsync -avzh --progress --stats $MASTER_NODE:~/ntu-icl-hackathon/configs/kubeconfig-* ./configs/

# users are only on node-001
rsync -avzh --progress --stats ./configs/kubeconfig-* $1:~/ntu-icl-hackathon/configs/
run_on_node $1 "cd ntu-icl-hackathon && ./scripts/access/create_users.sh"
rsync -avzh --progress --stats $1:~/ntu-icl-hackathon/user_keys/ ./user_keys/

# admins are on all nodes
for node in $@; do
    rsync -avzh --progress --stats ./configs/kubeconfig-admin $node:~/ntu-icl-hackathon/configs/
    run_on_node $node "cd ntu-icl-hackathon && ./scripts/access/create_admins.sh"
done

# deploy mysql and redis

run_on_node $MASTER_NODE "cd ntu-icl-hackathon && ./scripts/mysql-redis/deploy-shared-services.sh"

# deploy monitoring

run_on_node $MASTER_NODE "cd ntu-icl-hackathon && ./scripts/monitoring-stack/setup_monitoring_stack.sh"
