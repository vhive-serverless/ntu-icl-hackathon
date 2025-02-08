#!/bin/bash

docker build -t nehalem90/ntu-icl-hackathon-producer:latest -f producer/Dockerfile.producer .
docker build -t nehalem90/ntu-icl-hackathon-consumer:latest -f consumer/Dockerfile.consumer .

docker push nehalem90/ntu-icl-hackathon-producer:latest
docker push nehalem90/ntu-icl-hackathon-consumer:latest