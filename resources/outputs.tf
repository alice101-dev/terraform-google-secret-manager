output "secret_ids" {
  description = "Map of secret key => full resource ID (projects/../secrets/..)."
  value       = { for k, m in module.secrets : k => m.id }
}

output "rotation_topic" {
  description = "Pub/Sub topic that receives rotation-schedule notifications."
  value       = google_pubsub_topic.secret_rotation.id
}

output "bootstrap_versions" {
  description = "Resource IDs of the versions Terraform bootstrapped (metadata only — the payloads are write-only and never in state)."
  value       = { for k, v in google_secret_manager_secret_version.bootstrap : k => v.id }
}
