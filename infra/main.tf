# Everything deploy.sh set up, written down as code. Terraform owns the settings; the code itself
# (the container image) is still built and shipped by ship.sh, so the two don't fight.

data "google_project" "this" {}

locals {
  apis = [
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
    "places.googleapis.com",
    "geocoding-backend.googleapis.com",
    "maps-backend.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "billingbudgets.googleapis.com",
  ]
}

# ---------- APIs ----------

resource "google_project_service" "apis" {
  for_each = toset(local.apis)
  service  = each.value
  # Removing this file from Terraform must never switch an API off under a running app.
  disable_on_destroy = false
}

# ---------- Service accounts ----------

resource "google_service_account" "runtime" {
  account_id   = "${var.service}-sa"
  display_name = "Restaurant review service"
}

resource "google_service_account" "build" {
  account_id   = "${var.service}-build"
  display_name = "Restaurant review builds"
}

# Read and write the Firestore cache.
resource "google_project_iam_member" "runtime_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = google_service_account.runtime.member
}

# Read uploaded source, push images, write build logs.
resource "google_project_iam_member" "build_run_builder" {
  project = var.project_id
  role    = "roles/run.builder"
  member  = google_service_account.build.member
}

# ---------- Firestore ----------

resource "google_firestore_database" "default" {
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
  # ABANDON: "terraform destroy" forgets the database instead of deleting your data.
  deletion_policy = "ABANDON"
  depends_on      = [google_project_service.apis]
}

# Cache entries delete themselves once expires_at has passed.
resource "google_firestore_field" "cache_ttl" {
  database   = google_firestore_database.default.name
  collection = "query_cache"
  field      = "expires_at"
  ttl_config {}
}

# ---------- Secrets (names and access only; values are added with gcloud) ----------

resource "google_secret_manager_secret" "app" {
  for_each  = var.secrets
  secret_id = each.value
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "runtime_reads" {
  for_each  = google_secret_manager_secret.app
  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runtime.member
}

# ---------- Artifact Registry (where Cloud Run source deploys put images) ----------

resource "google_artifact_registry_repository" "images" {
  repository_id = "cloud-run-source-deploy"
  location      = var.region
  format        = "DOCKER"
  description   = "Cloud Run Source Deployments"

  # Storage over 0.5 GB is billed, so old images are cleaned up. KEEP wins over DELETE.
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-latest-3"
    action = "KEEP"
    most_recent_versions {
      keep_count = 3
    }
  }
  cleanup_policies {
    id     = "delete-older-than-7-days"
    action = "DELETE"
    condition {
      tag_state  = "ANY"
      older_than = "7d"
    }
  }
}

# ---------- Cloud Run ----------

resource "google_cloud_run_v2_service" "app" {
  name     = var.service
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  # Public without the allUsers grant your organization policy blocks
  # (the same as: gcloud run services update --no-invoker-iam-check).
  invoker_iam_disabled = true

  template {
    service_account                  = google_service_account.runtime.email
    timeout                          = "30s"
    max_instance_request_concurrency = 40

    scaling {
      min_instance_count = 0 # nothing running, nothing billed, when idle
      max_instance_count = var.max_instances
    }

    containers {
      # Placeholder only: ship.sh deploys the real image, and Terraform ignores it (see lifecycle below).
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        # Must be stated once "resources" is set: CPU only while handling a request (the cheaper billing).
        cpu_idle          = true
        startup_cpu_boost = true
      }

      env {
        name  = "STORE"
        value = "firestore"
      }
      env {
        name  = "GCP_PROJECT"
        value = var.project_id
      }
      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }
      env {
        name  = "TRIPADVISOR_DAILY_ENTITY_LIMIT"
        value = tostring(var.tripadvisor_daily_entity_limit)
      }
      env {
        name  = "TRIPADVISOR_MARKETS"
        value = var.tripadvisor_markets # commas are fine here, unlike gcloud flags
      }

      dynamic "env" {
        for_each = var.maps_browser_key == "" ? {} : {
          GOOGLE_MAPS_BROWSER_KEY = var.maps_browser_key
          GOOGLE_MAP_ID           = var.map_id
        }
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.app[env.key].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image, # set by each code deploy
      client,                          # gcloud stamps its name/version on each deploy
      client_version,
      build_config, # source-deploy build details
    ]
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.runtime_reads,
  ]
}

# ---------- Budget alert (optional) ----------
# Emails billing admins at 50%, 90% and 100% of the amount, and when the month is forecast to go over.
# An alert only; it never stops anything.

resource "google_billing_budget" "monthly" {
  count           = var.billing_account == "" ? 0 : 1
  billing_account = var.billing_account
  display_name    = "${var.project_id} monthly"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      units = tostring(var.budget_usd) # in the billing account's currency
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  depends_on = [google_project_service.apis]
}
