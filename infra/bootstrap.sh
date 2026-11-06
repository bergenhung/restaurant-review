#!/usr/bin/env bash
# One time: make the Cloud Storage bucket that holds Terraform's state, then run terraform init.
# Terraform can't create the bucket it keeps its own state in, so this one step is gcloud.
#
# Usage (from the infra folder):  PROJECT_ID=restaurants-review-summary ./bootstrap.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
# Accept the project number too (e.g. 981869842988): some commands (Firestore) only take the ID.
PROJECT_ID="$(gcloud projects describe "$PROJECT_ID" --format='value(projectId)')"
REGION="${REGION:-us-west1}"     # us-west1/us-central1/us-east1 are in the 5 GB always-free storage tier
BUCKET="${PROJECT_ID}-tfstate"

gcloud config set project "$PROJECT_ID" >/dev/null

# Terraform sends its calls under this project (user_project_override in versions.tf), so the APIs it
# needs before it can enable anything itself must already be on. They're free switches.
echo "==> Enabling the APIs Terraform needs to start"
gcloud services enable cloudresourcemanager.googleapis.com serviceusage.googleapis.com \
  iam.googleapis.com billingbudgets.googleapis.com --project "$PROJECT_ID"

if ! gcloud storage buckets describe "gs://$BUCKET" >/dev/null 2>&1; then
  echo "==> Creating gs://$BUCKET"
  gcloud storage buckets create "gs://$BUCKET" --location="$REGION" \
    --uniform-bucket-level-access --public-access-prevention
fi
# Versioning keeps earlier copies of the state file, so a bad apply can be rolled back.
gcloud storage buckets update "gs://$BUCKET" --versioning \
  --update-labels=app=restaurant-review,lab=p1-terraform >/dev/null

# Terraform signs in with your Cloud Shell identity.
gcloud auth application-default print-access-token >/dev/null 2>&1 || gcloud auth application-default login

terraform init -backend-config="bucket=$BUCKET"
echo
echo "Next: cp terraform.tfvars.example terraform.tfvars, edit it, then:  terraform plan"
