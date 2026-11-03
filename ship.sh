#!/usr/bin/env bash
# Ship new code once Terraform manages the setup (see infra/README.md).
# Builds the image and rolls out a new revision; settings, secrets and scaling stay as Terraform set them,
# because gcloud keeps whatever isn't passed as a flag.
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
# Accept the project number too (e.g. 981869842988): some commands (Firestore) only take the ID.
PROJECT_ID="$(gcloud projects describe "$PROJECT_ID" --format='value(projectId)')"
REGION="${REGION:-us-west1}"
SERVICE="${SERVICE:-restaurant-review}"

gcloud run deploy "$SERVICE" \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --source . \
  --build-service-account "projects/${PROJECT_ID}/serviceAccounts/${SERVICE}-build@${PROJECT_ID}.iam.gserviceaccount.com" \
  --quiet

URL=$(gcloud run services describe "$SERVICE" --project "$PROJECT_ID" --region "$REGION" --format='value(status.url)')
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$URL/healthz" || true)
echo "Health check: HTTP $STATUS   $URL/"
