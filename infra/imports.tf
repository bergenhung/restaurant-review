# These already exist (deploy.sh made them). Import blocks tell Terraform "adopt this, don't create it".
# Once the first apply has succeeded they do nothing, so they can stay or be deleted.

import {
  to = google_service_account.runtime
  id = "projects/${var.project_id}/serviceAccounts/${var.service}-sa@${var.project_id}.iam.gserviceaccount.com"
}

import {
  to = google_service_account.build
  id = "projects/${var.project_id}/serviceAccounts/${var.service}-build@${var.project_id}.iam.gserviceaccount.com"
}

import {
  to = google_firestore_database.default
  id = "projects/${var.project_id}/databases/(default)"
}

import {
  to = google_secret_manager_secret.app["GOOGLE_PLACES_API_KEY"]
  id = "projects/${var.project_id}/secrets/google-places-api-key"
}

import {
  to = google_secret_manager_secret.app["TRIPADVISOR_API_KEY"]
  id = "projects/${var.project_id}/secrets/tripadvisor-api-key"
}

import {
  to = google_artifact_registry_repository.images
  id = "projects/${var.project_id}/locations/${var.region}/repositories/cloud-run-source-deploy"
}

import {
  to = google_cloud_run_v2_service.app
  id = "projects/${var.project_id}/locations/${var.region}/services/${var.service}"
}
