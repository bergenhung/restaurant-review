# Cloud practice roadmap

Each project has a short ID to refer to it by ("let's do P3"). The same ID goes on the
resources it creates, as the label `lab=<id>`. In **Billing → Reports → Group by → Label → lab**
you can then see what each one costs.

| ID | Label | Project | What you practise | Expected cost |
|---|---|---|---|---|
| P0 | `p0-app` | The restaurant review service on Cloud Run (done) | Cloud Run, Firestore, Secret Manager, IAM | $0 idle; Google/Tripadvisor API usage |
| P1 | `p1-terraform` | **Terraform for P0** (in progress: `infra/`) | Infrastructure as code, state, imports, drift, budget alert | $0 |
| P2 | `p2-cicd` | GitHub Actions deploys on push, signed in with Workload Identity Federation | CI/CD, keyless auth, least privilege | $0 (Cloud Build free minutes) |
| P3 | `p3-jobs` | Cloud Scheduler + Cloud Run job (e.g. refresh the Michelin lists nightly) | Jobs vs services, cron, retries | $0 (3 free scheduler jobs) |
| P4 | `p4-monitoring` | Uptime check, alert policy, log-based metric, dashboard | Observability, alerting | $0 |
| P5 | `p5-bigquery` | Log sink to BigQuery, query searches and latency | Log routing, SQL analytics | $0 within free query/storage |
| P6 | `p6-vm` | The app on an e2-micro VM, no public IP, reached through IAP | Compute Engine, VPC, firewall, IAP | $0 (always-free e2-micro in us-west1) |
| P7 | `p7-multiregion` | us-west1, us-east1, asia-east1 behind a global load balancer | Multi-region VPC, global LB, managed certs | ~$18+/month while running; time-boxed, then torn down |

## Organization layout

```
Organization
└── Folder "portfolio"
    └── restaurants-review-summary   (P0–P5)
    └── (later) a separate lab project for P6–P7, so it can be deleted in one go
```

## Done log

- P0: deployed at https://restaurant-review-981869842988.us-west1.run.app
