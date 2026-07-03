output "id" {
  description = "Full resource ID: projects/{project}/secrets/{secret_id}."
  value       = google_secret_manager_secret.this.id
}

output "name" {
  description = "Resource name of the secret."
  value       = google_secret_manager_secret.this.name
}

output "secret_id" {
  description = "Short secret ID."
  value       = google_secret_manager_secret.this.secret_id
}
