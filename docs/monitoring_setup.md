# Monitoring Setup

## Grafana

### Accessing Grafana

Port-forwarding to local machine:

```bash
ssh -L 3000:localhost:3000 <username>@<master-node-ip>
```

The default credentials are:
- Username: admin
- Password: prom-operator (will change after first login, distributed in the chat)