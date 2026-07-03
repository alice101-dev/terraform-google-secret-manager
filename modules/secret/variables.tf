variable "secret_id" {
  description = "ID of the secret (letters, digits, underscores and hyphens; max 255 chars)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,255}$", var.secret_id))
    error_message = "secret_id may only contain letters, digits, underscores and hyphens (max 255 chars)."
  }
}

variable "project_id" {
  description = "Project ID that owns the secret."
  type        = string
}

variable "labels" {
  description = "Labels attached to the secret (e.g. app, env, owner)."
  type        = map(string)
  default     = {}
}

variable "replica_locations" {
  description = <<-EOT
    Regions for user-managed replication (data residency). Leave empty for
    automatic replication, where Google chooses the regions.
  EOT
  type        = list(string)
  default     = []
}

variable "kms_key_name" {
  description = <<-EOT
    Optional CMEK key (projects/../locations/../keyRings/../cryptoKeys/..) used
    to encrypt the secret payload instead of Google-managed encryption. With
    user-managed replication the key's location must match each replica.
  EOT
  type        = string
  default     = null
}

variable "ttl" {
  description = "Optional time-to-live in seconds with a trailing 's' (e.g. \"86400s\"). The secret is deleted when the TTL expires — use for short-lived credentials only."
  type        = string
  default     = null

  validation {
    condition     = var.ttl == null || can(regex("^[0-9]+s$", var.ttl))
    error_message = "ttl must be an integer number of seconds suffixed with 's', e.g. \"86400s\"."
  }
}

variable "rotation_period" {
  description = "Optional rotation reminder interval in seconds with a trailing 's' (e.g. 30 days = \"2592000s\"). Requires notification_topics."
  type        = string
  default     = null

  validation {
    condition     = var.rotation_period == null || can(regex("^[0-9]+s$", var.rotation_period))
    error_message = "rotation_period must be an integer number of seconds suffixed with 's', e.g. \"2592000s\"."
  }
}

variable "next_rotation_time" {
  description = "RFC-3339 timestamp of the first rotation reminder (e.g. \"2026-08-01T00:00:00Z\"). Required when rotation_period is set."
  type        = string
  default     = null

  validation {
    condition     = var.next_rotation_time == null || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?Z$", var.next_rotation_time))
    error_message = "next_rotation_time must be an RFC-3339 UTC timestamp, e.g. \"2026-08-01T00:00:00Z\"."
  }
}

variable "notification_topics" {
  description = "Full Pub/Sub topic names (projects/../topics/..) notified on rotation schedule and version events."
  type        = list(string)
  default     = []
}

variable "accessors" {
  description = "Principals granted roles/secretmanager.secretAccessor on THIS secret only (e.g. serviceAccount:app@project.iam.gserviceaccount.com)."
  type        = list(string)
  default     = []
}

variable "version_adders" {
  description = "Principals granted roles/secretmanager.secretVersionAdder on this secret (rotation automation: may add versions, cannot read them)."
  type        = list(string)
  default     = []
}

variable "admins" {
  description = "Principals granted roles/secretmanager.admin on this secret only."
  type        = list(string)
  default     = []
}
