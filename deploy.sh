#!/usr/bin/env bash
# One-time setup and deploy to Cloud Run. Safe to re-run: each step skips what already exists.
#
# Usage:
#   export PROJECT_ID=my-project
#   export GOOGLE_PLACES_API_KEY=...        # first run only; stored in Secret Manager
#   export TRIPADVISOR_API_KEY=...          # optional, Terra key
#   export YELP_API_KEY=...                 # optional, paid
#   export GOOGLE_MAPS_BROWSER_KEY=...      # optional, shows the results map
#   export GOOGLE_MAP_ID=...                # optional, defaults to DEMO_MAP_ID
#   ./deploy.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
REGION="${REGION:-us-west1}"
SERVICE="${SERVICE:-restaurant-review}"
SA_NAME="${SERVICE}-sa"
SA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud config set project "$PROJECT_ID" >/dev/null

echo "==> Enabling APIs"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
  firestore.googleapis.com secretmanager.googleapis.com places.googleapis.com

echo "==> Firestore (Native mode, free tier applies to the (default) database)"
if ! gcloud firestore databases describe --database="(default)" >/dev/null 2>&1; then
  gcloud firestore databases create --database="(default)" --location="$REGION" --type=firestore-native
fi
# Deletes expired cache entries automatically.
gcloud firestore fields ttls update expires_at --collection-group=query_cache --enable-ttl --async >/dev/null 2>&1 || true

echo "==> Service account"
if ! gcloud iam service-accounts describe "$SA" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SA_NAME" --display-name="Restaurant review service"
fi

# Builds run as their own service account, separate from the app's, so the running app never gets
# permission to read uploaded source or push images (and the project's default account needs no extra roles).
BUILD_SA_NAME="${SERVICE}-build"
BUILD_SA="${BUILD_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "==> Build service account"
if ! gcloud iam service-accounts describe "$BUILD_SA" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$BUILD_SA_NAME" --display-name="Restaurant review builds"
fi
# Cloud Run Builder: read the uploaded source, push the image to Artifact Registry, write build logs.
if ! gcloud projects get-iam-policy "$PROJECT_ID" --flatten='bindings[].members' \
     --filter="bindings.role=roles/run.builder AND bindings.members=serviceAccount:${BUILD_SA}" \
     --format='value(bindings.role)' 2>/dev/null | grep -q run.builder; then
  gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${BUILD_SA}" \
    --role=roles/run.builder --condition=None >/dev/null
  # New permissions take a minute or two to apply; building straight away fails with a 403.
  echo "    Waiting 90s for the new permission to take effect..."
  sleep 90
fi
 
echo "==> Secrets"
SECRETS="GOOGLE_PLACES_API_KEY=google-places-api-key:latest"
put_secret() {  # name value
  if ! gcloud secrets describe "$1" >/dev/null 2>&1; then
    printf '%s' "$2" | gcloud secrets create "$1" --data-file=- --replication-policy=automatic
  elif [ -n "$2" ]; then
    printf '%s' "$2" | gcloud secrets versions add "$1" --data-file=-
  fi
  gcloud secrets add-iam-policy-binding "$1" --member="serviceAccount:$SA" \
    --role=roles/secretmanager.secretAccessor >/dev/null
}
if ! gcloud secrets describe google-places-api-key >/dev/null 2>&1 && [ -z "${GOOGLE_PLACES_API_KEY:-}" ]; then
  echo "GOOGLE_PLACES_API_KEY is required on the first run." >&2; exit 1
fi
put_secret google-places-api-key "${GOOGLE_PLACES_API_KEY:-}"
if [ -n "${YELP_API_KEY:-}" ] || gcloud secrets describe yelp-api-key >/dev/null 2>&1; then
  put_secret yelp-api-key "${YELP_API_KEY:-}"
  SECRETS="$SECRETS,YELP_API_KEY=yelp-api-key:latest"
fi
if [ -n "${TRIPADVISOR_API_KEY:-}" ] || gcloud secrets describe tripadvisor-api-key >/dev/null 2>&1; then
  put_secret tripadvisor-api-key "${TRIPADVISOR_API_KEY:-}"
  SECRETS="$SECRETS,TRIPADVISOR_API_KEY=tripadvisor-api-key:latest"
fi

# Settings for the app. Values can contain commas (TRIPADVISOR_MARKETS=us,tw), so they're joined
# with "@" and passed as "^@^A=1@B=2": the ^@^ prefix tells gcloud to split on @ instead of commas.
ENV_LIST=(
  "STORE=firestore"
  "GCP_PROJECT=$PROJECT_ID"
  "LOG_LEVEL=INFO"
  # Tripadvisor's daily cap is counted per running instance; with up to 3 instances the real
  # ceiling is up to 3x this, so the default here is lower than for local runs.
  "TRIPADVISOR_DAILY_ENTITY_LIMIT=${TRIPADVISOR_DAILY_ENTITY_LIMIT:-10}"
  "TRIPADVISOR_MARKETS=${TRIPADVISOR_MARKETS:-us,tw}"
)
# The map key is visible in the browser by design, so it's a plain setting rather than a secret.
if [ -n "${GOOGLE_MAPS_BROWSER_KEY:-}" ]; then
  ENV_LIST+=("GOOGLE_MAPS_BROWSER_KEY=$GOOGLE_MAPS_BROWSER_KEY" "GOOGLE_MAP_ID=${GOOGLE_MAP_ID:-DEMO_MAP_ID}")
fi
ENV_VARS="^@^$(IFS=@; echo "${ENV_LIST[*]}")"

echo "==> Building and deploying"
# max-instances caps spending if the service gets hammered; min-instances 0 means no cost when idle.
gcloud run deploy "$SERVICE" \
  --source . \
  --region "$REGION" \
  --service-account "$SA" \
  --build-service-account "projects/${PROJECT_ID}/serviceAccounts/${BUILD_SA}" \
  --no-invoker-iam-check \
  --set-env-vars "$ENV_VARS" \
  --set-secrets "$SECRETS" \
  --cpu 1 --memory 512Mi --concurrency 40 \
  --min-instances 0 --max-instances 3 \
  --timeout 30

URL=$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')
echo
echo "Deployed: $URL"
echo "Try:      $URL/v1/top?location=Seattle&cuisine=ramen&format=html"
