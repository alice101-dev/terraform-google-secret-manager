variable "project_id" {
  description = "Project ID that hosts the secrets."
  type        = string
}

variable "rotation_topic_name" {
  description = "Name of the Pub/Sub topic that receives rotation-schedule notifications."
  type        = string
  default     = "secret-rotation-events"
}

variable "rotation_topic_kms_key" {
  description = "Optional CMEK key for the rotation topic. The messages contain only rotation-schedule metadata (no secret payloads), so Google-managed encryption is usually sufficient."
  type        = string
  default     = null
}

variable "secrets" {
  description = <<-EOT
    Map of secrets to create. The map key becomes the secret_id. Secrets with a
    rotation_period are wired to the rotation Pub/Sub topic automatically.
  EOT
  type = map(object({
    labels            = optional(map(string), {})
    replica_locations = optional(list(string), [])
    kms_key_name      = optional(string)
    ttl               = optional(string)

    rotation_period    = optional(string)
    next_rotation_time = optional(string)

    accessors      = optional(list(string), [])
    version_adders = optional(list(string), [])
    admins         = optional(list(string), [])
  }))
}

variable "bootstrap_secret_names" {
  description = <<-EOT
    Keys of var.secrets that get an initial version created by Terraform (via
    the write-only secret_data_wo attribute — plaintext never enters state).
    Values come from var.bootstrap_secret_values.
  EOT
  type        = list(string)
  default     = []
}

variable "bootstrap_secret_values" {
  description = <<-EOT
    Secret values for bootstrap_secret_names, keyed by secret name. EPHEMERAL:
    never persisted to state or plan. Pass at apply time, e.g.
      TF_VAR_bootstrap_secret_values='{"db-password":"s3cr3t"}' terraform apply
  EOT
  type        = map(string)
  default     = null
  ephemeral   = true
  sensitive   = true
}

variable "bootstrap_secret_wo_version" {
  description = "Version counter for the write-only secret values. Bump it to push new values for the bootstrap secrets."
  type        = number
  default     = 1
}

variable "auditor_principals" {
  description = "Principals granted roles/logging.privateLogViewer to read Secret Manager Data Access audit logs."
  type        = list(string)
  default     = []
}
