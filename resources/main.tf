# ---------------------------------------------------------------------------
# Enable required APIs
# ---------------------------------------------------------------------------
locals {
  required_services = [
    "secretmanager.googleapis.com",
    "pubsub.googleapis.com", # rotation notifications
    "logging.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_services)

  project = var.project_id
  service = each.value

  # Keep APIs enabled even if this config is destroyed — other workloads rely on them.
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Rotation notification topic
#
# Secret Manager publishes a message here whenever a secret hits its rotation
# schedule (and on version events). Subscribe your rotation automation or
# alerting to this topic.
# ---------------------------------------------------------------------------
resource "google_pubsub_topic" "secret_rotation" {
  # checkov:skip=CKV_GCP_83:Messages carry only rotation-schedule metadata (secret name + event type),
  # never secret payloads. Set rotation_topic_kms_key to opt in to CMEK anyway.
  name         = var.rotation_topic_name
  project      = var.project_id
  kms_key_name = var.rotation_topic_kms_key

  depends_on = [google_project_service.required]
}

# The Secret Manager service agent must exist and be allowed to publish.
resource "google_project_service_identity" "secretmanager" {
  provider = google-beta

  project = var.project_id
  service = "secretmanager.googleapis.com"

  depends_on = [google_project_service.required]
}

resource "google_pubsub_topic_iam_member" "secretmanager_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.secret_rotation.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_project_service_identity.secretmanager.email}"
}

# ---------------------------------------------------------------------------
# Secrets
#
# One module instance per entry in var.secrets. Secrets with a rotation_period
# are automatically wired to the rotation topic above.
# ---------------------------------------------------------------------------
module "secrets" {
  source   = "../modules/secret"
  for_each = var.secrets

  secret_id  = each.key
  project_id = var.project_id

  labels            = each.value.labels
  replica_locations = each.value.replica_locations
  kms_key_name      = each.value.kms_key_name
  ttl               = each.value.ttl

  rotation_period     = each.value.rotation_period
  next_rotation_time  = each.value.next_rotation_time
  notification_topics = each.value.rotation_period != null ? [google_pubsub_topic.secret_rotation.id] : []

  accessors      = each.value.accessors
  version_adders = each.value.version_adders
  admins         = each.value.admins

  depends_on = [
    google_project_service.required,
    google_pubsub_topic_iam_member.secretmanager_publisher,
  ]
}

# ---------------------------------------------------------------------------
# Bootstrap secret versions — WITHOUT the plaintext touching Terraform state.
#
# secret_data_wo is a WRITE-ONLY attribute: Terraform sends the value to the
# API but never stores it in state or plan files. Combined with an ephemeral
# variable, the value only ever lives in memory for the duration of the apply:
#
#   TF_VAR_bootstrap_secret_values='{"db-password":"s3cr3t"}' terraform apply
#
# Bump bootstrap_secret_wo_version to push a new value for a key.
# Day-2 rotation can equally use gcloud:
#   gcloud secrets versions add db-password --data-file=- <<< "$NEW_VALUE"
# ---------------------------------------------------------------------------
resource "google_secret_manager_secret_version" "bootstrap" {
  for_each = toset(var.bootstrap_secret_names)

  secret                 = module.secrets[each.value].id
  secret_data_wo         = var.bootstrap_secret_values[each.value]
  secret_data_wo_version = var.bootstrap_secret_wo_version

  lifecycle {
    precondition {
      condition     = var.bootstrap_secret_values != null && contains(keys(var.bootstrap_secret_values), each.value)
      error_message = "bootstrap_secret_values must provide a value for '${each.value}' (set it via TF_VAR_bootstrap_secret_values)."
    }
  }
}

# ---------------------------------------------------------------------------
# Audit logging
#
# Data Access logs for Secret Manager are OFF by default. Enable them so every
# AccessSecretVersion call is recorded, and give auditors read access.
# ---------------------------------------------------------------------------
resource "google_project_iam_audit_config" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_project_iam_member" "auditors_private_log_viewer" {
  for_each = toset(var.auditor_principals)

  project = var.project_id
  role    = "roles/logging.privateLogViewer"
  member  = each.value
}
