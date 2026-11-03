variable "project_id" {
  description = "The Google Cloud project, e.g. restaurants-review-summary"
  type        = string
}

variable "region" {
  description = "Where Cloud Run, Firestore and Artifact Registry live"
  type        = string
  default     = "us-west1"
}

variable "service" {
  description = "Cloud Run service name"
  type        = string
  default     = "restaurant-review"
}

variable "secrets" {
  description = "App setting name => Secret Manager secret ID. Only the secret's name is managed here, never its value."
  type        = map(string)
  default = {
    GOOGLE_PLACES_API_KEY = "google-places-api-key"
    TRIPADVISOR_API_KEY   = "tripadvisor-api-key"
  }
}

variable "tripadvisor_daily_entity_limit" {
  description = "Billable Tripadvisor items per day, per running instance"
  type        = number
  default     = 10
}

variable "tripadvisor_markets" {
  type    = string
  default = "us,tw"
}

variable "maps_browser_key" {
  description = "Browser key for the results map. It's visible in web pages by design, so it isn't a secret."
  type        = string
  default     = ""
}

variable "map_id" {
  type    = string
  default = "DEMO_MAP_ID"
}

variable "max_instances" {
  description = "Upper limit on running copies; caps the bill if the site gets hammered"
  type        = number
  default     = 3
}

# ---- Budget alert (optional) ----

variable "billing_account" {
  description = "Billing account ID like 012345-6789AB-CDEF01. Leave empty to skip the budget alert."
  type        = string
  default     = ""
}

variable "budget_usd" {
  description = "Monthly amount the alert emails are based on"
  type        = number
  default     = 10
}
