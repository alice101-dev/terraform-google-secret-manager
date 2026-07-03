# Project that hosts the secrets (example values — edit before applying).
project_id = "example-secrets-project"

# Who can read the Secret Manager Data Access audit logs.
auditor_principals = [
  "group:security-auditors@example.com",
]

# ---------------------------------------------------------------------------
# Secrets. The map key is the secret_id.
# ---------------------------------------------------------------------------
secrets = {
  # Backend database password: pinned to Jakarta (data residency), rotation
  # reminder every 30 days, readable only by the backend's service account.
  "db-password" = {
    labels            = { app = "backend", env = "prod" }
    replica_locations = ["asia-southeast2"]

    rotation_period    = "2592000s" # 30 days
    next_rotation_time = "2026-08-01T00:00:00Z"

    accessors = [
      "serviceAccount:app-backend@example-secrets-project.iam.gserviceaccount.com",
    ]
    version_adders = [
      "serviceAccount:rotation-bot@example-secrets-project.iam.gserviceaccount.com",
    ]
  }

  # Third-party API key: automatic replication, quarterly rotation reminder.
  "external-api-key" = {
    labels = { app = "backend", env = "prod" }

    rotation_period    = "7776000s" # 90 days
    next_rotation_time = "2026-10-01T00:00:00Z"

    accessors = [
      "serviceAccount:app-backend@example-secrets-project.iam.gserviceaccount.com",
    ]
  }

  # Webhook signing secret for CI: no rotation schedule, admin delegated to
  # the platform team for this one secret only.
  "ci-webhook-secret" = {
    labels = { app = "ci", env = "shared" }

    accessors = [
      "serviceAccount:ci-runner@example-secrets-project.iam.gserviceaccount.com",
    ]
    admins = [
      "group:platform-admins@example.com",
    ]
  }
}

# Secrets that get their FIRST version from Terraform (write-only, never in
# state). Provide the values at apply time:
#   TF_VAR_bootstrap_secret_values='{"db-password":"..."}' terraform apply
bootstrap_secret_names = ["db-password"]
