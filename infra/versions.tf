terraform {
  # 1.6+ for import blocks whose IDs use variables (imports.tf). Check with: terraform version
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  # State is kept in a Cloud Storage bucket so it survives Cloud Shell resets and isn't on one machine.
  # The bucket name is passed at init time:  terraform init -backend-config="bucket=PROJECT_ID-tfstate"
  backend "gcs" {
    prefix = "restaurant-review"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Some APIs (budgets) need to know which project to bill the API calls to when you're signed in as yourself.
  user_project_override = true
  billing_project       = var.project_id

  # Added to every resource that supports labels. Billing > Reports can then group costs by "lab".
  default_labels = {
    app        = var.service
    lab        = "p0-app"
    managed-by = "terraform"
  }
}
