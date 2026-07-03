# ---------------------------------------------------------------------------
# Secret Manager secret
#
# One secret with opinionated defaults:
#   - replication: automatic, or user-managed when replica_locations is set
#   - optional CMEK (kms_key_name) on either replication mode
#   - optional rotation reminder (requires a Pub/Sub notification topic)
#   - per-secret least-privilege IAM (accessors / version adders / admins)
#
# Secret VALUES are intentionally out of scope: versions are added with the
# write-only secret_data_wo attribute or via gcloud, so plaintext never lands
# in the Terraform state. See the repo README.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8.0"
    }
  }
}

resource "google_secret_manager_secret" "this" {
  secret_id = var.secret_id
  project   = var.project_id
  labels    = var.labels
  ttl       = var.ttl

  replication {
    # Automatic replication when no explicit locations are requested.
    dynamic "auto" {
      for_each = length(var.replica_locations) == 0 ? [1] : []
      content {
        dynamic "customer_managed_encryption" {
          for_each = var.kms_key_name != null ? [1] : []
          content {
            kms_key_name = var.kms_key_name
          }
        }
      }
    }

    # User-managed replication pins the secret to specific regions
    # (data-residency / latency requirements).
    dynamic "user_managed" {
      for_each = length(var.replica_locations) > 0 ? [1] : []
      content {
        dynamic "replicas" {
          for_each = var.replica_locations
          content {
            location = replicas.value
            dynamic "customer_managed_encryption" {
              for_each = var.kms_key_name != null ? [1] : []
              content {
                kms_key_name = var.kms_key_name
              }
            }
          }
        }
      }
    }
  }

  # Rotation is a REMINDER: Secret Manager publishes a message to the topics
  # below on schedule; an operator or automation then adds the new version.
  dynamic "rotation" {
    for_each = var.rotation_period != null ? [1] : []
    content {
      rotation_period    = var.rotation_period
      next_rotation_time = var.next_rotation_time
    }
  }

  dynamic "topics" {
    for_each = var.notification_topics
    content {
      name = topics.value
    }
  }

  lifecycle {
    precondition {
      condition     = var.rotation_period == null || var.next_rotation_time != null
      error_message = "next_rotation_time is required when rotation_period is set (secret ${var.secret_id})."
    }
    # The API rejects a rotation schedule without at least one notification topic.
    precondition {
      condition     = var.rotation_period == null || length(var.notification_topics) > 0
      error_message = "rotation_period requires at least one notification topic (secret ${var.secret_id})."
    }
  }
}

# ---------------------------------------------------------------------------
# Per-secret IAM — least privilege, no project-wide grants.
# ---------------------------------------------------------------------------

# Workloads that READ the secret value at runtime.
resource "google_secret_manager_secret_iam_member" "accessors" {
  for_each = toset(var.accessors)

  project   = var.project_id
  secret_id = google_secret_manager_secret.this.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}

# Rotation automation that WRITES new versions (cannot read existing ones).
resource "google_secret_manager_secret_iam_member" "version_adders" {
  for_each = toset(var.version_adders)

  project   = var.project_id
  secret_id = google_secret_manager_secret.this.secret_id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = each.value
}

# Humans who manage THIS secret's settings and IAM (not every secret).
resource "google_secret_manager_secret_iam_member" "admins" {
  for_each = toset(var.admins)

  project   = var.project_id
  secret_id = google_secret_manager_secret.this.secret_id
  role      = "roles/secretmanager.admin"
  member    = each.value
}
