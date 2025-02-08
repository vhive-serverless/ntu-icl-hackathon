#!/bin/bash

curl -X POST http://producer.example.192.168.1.240.sslip.io \
  -H "Content-Type: application/json" \
  -d '{"message": "Test message"}'
