#!/bin/bash

run_on_node() {
    ssh $1 $2
}

# clone repo and setup node on all nodes

setup_node() {
    scp -r ../ntu-icl-hackathon $1:~/ntu-icl-hackathon
    # run_on_node $1 "git clone https://github.com/ntu-icl-hackathon/ntu-icl-hackathon.git"
    run_on_node $1 "cd ntu-icl-hackathon && git checkout dev"
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
