# Monitoring Setup

## Grafana

### Accessing Grafana

Grafana address can be obtained by running `kubectl get svc -o json -n monitoring | jq '.items[] | {name:.metadata.name, p:.spec.ports[] } | select( .p.nodePort != null ) | "\(.name): localhost:\(.p.nodePort)"'`

Port-forwarding to local machine:

```bash
ssh -L 3000:localhost:<given-port> <username>@<master-node-ip>
```

The default credentials are:
- Username: admin
- Password: prom-operator (will change after first login, distributed in the chat)