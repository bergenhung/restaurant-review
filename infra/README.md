# P1 · Terraform for the restaurant review service

This folder describes what `deploy.sh` set up by hand as code:
- APIs
- the two service accounts and their roles
- Firestore and its cache TTL
- the secrets (names only)
- Artifact Registry with a cleanup policy
- the Cloud Run service
- an optional budget alert

Terraform **adopts** the existing resources (`imports.tf`); it doesn't recreate them, and the site stays up.

| Who does what | Tool |
|---|---|
| Settings, scaling, accounts, permissions | `terraform apply` (this folder) |
| New code | `./ship.sh` (repo root) |
| Secret values | `gcloud secrets versions add …` (values never go into Terraform) |

Once this is set up, use `ship.sh` instead of `deploy.sh`. Running `deploy.sh` again won't break anything, but its settings would drift from what's written here.

## Cost

Practically $0:
- The state file is a few KB in a bucket in us-west1, which is in the always-free 5 GB.
- Terraform itself is free and is already installed in Cloud Shell.

Every resource gets the labels `lab=p0-app` and `managed-by=terraform`. In **Billing → Reports**, group by label `lab` to see cost per lab.

## First run (Cloud Shell)

```bash
cd ~/restaurant-review && git pull
cd infra
terraform version                      # needs 1.7 or newer
PROJECT_ID=restaurants-review-summary ./bootstrap.sh
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars                  # project_id; maps key and billing account if you use them
```

Before planning, save today's settings so you can compare them afterwards:

```bash
gcloud run services describe restaurant-review --region us-west1 \
  --format='yaml(spec.template.spec.containers[0].env)'
```

Then preview the changes:

```bash
terraform plan
```

**Read the plan before applying.** On the first run you should see:

- `N to import`: the existing resources being adopted.
- `to add`: only the API switches, the IAM grants, the TTL field and the budget (if set). All of these are safe to "add" even if they already exist.
- `to change`: mostly labels being added. You may also see the cleanup policy if you set one up in the console.
- **`0 to destroy`.** If the plan wants to destroy or replace (`-/+`) anything, stop and send me the plan.

If it shows `GOOGLE_MAPS_BROWSER_KEY` being removed, put the key in `terraform.tfvars` and plan again.

When the plan looks right, apply it:

```bash
terraform apply                        # shows the plan again; type yes
```

## Day to day

```bash
# change a setting, e.g. max_instances or the Tripadvisor cap, in terraform.tfvars or variables.tf
terraform plan && terraform apply

# ship code
cd .. && PROJECT_ID=restaurants-review-summary ./ship.sh

# see whether someone changed something by hand in the console
terraform plan                         # "No changes" = the live setup matches the code
```

## Learning notes

- **State:** Terraform's record of what it manages lives in `gs://PROJECT_ID-tfstate`. It's versioned, so earlier copies are kept. Don't edit it by hand.
- **`lifecycle.ignore_changes`** on the Cloud Run image is what lets `ship.sh` deploy code without Terraform undoing it.
- **`deletion_policy = "ABANDON"`** on Firestore: `terraform destroy` forgets the database but keeps your data. The Cloud Run service has `deletion_protection` (on by default) for the same reason.
- **`cpu_idle = true`:** without it, Cloud Run bills CPU for the whole time an instance is up, not just while it handles requests.
- Try drift detection: change max instances in the console, run `terraform plan`, and watch it offer to put the value back.
