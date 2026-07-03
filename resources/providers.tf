terraform {
  # >= 1.11 for write-only attributes (secret_data_wo) and ephemeral variables.
  required_version = ">= 1.11.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.0, < 8.0"
    }
  }

  # State is LOCAL by default so the repo runs with no extra infrastructure.
  # For remote state + locking, copy backend.tf.example to backend.tf.
}

provider "google" {
  project = var.project_id
}

# Only used for google_project_service_identity (Secret Manager service agent).
provider "google-beta" {
  project = var.project_id
}
