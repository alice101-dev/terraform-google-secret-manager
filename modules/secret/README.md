# Module: `secret`

Reusable wrapper around
[`google_secret_manager_secret`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret)
plus per-secret least-privilege IAM.

- **Replication** — automatic by default, or user-managed when
  `replica_locations` is set (data residency); optional **CMEK** on both modes.
- **Rotation reminder** — `rotation_period` + `next_rotation_time`, published
  to the Pub/Sub `notification_topics` (required by the API; preconditions
  fail the plan early if missing).
- **IAM** — `accessors` (read), `version_adders` (write new versions only),
  `admins` (manage this one secret), all scoped to the secret.
- **No values** — versions are intentionally out of scope; add them with the
  write-only `secret_data_wo` attribute or `gcloud secrets versions add` so
  plaintext never enters the Terraform state.

## Usage

```hcl
module "db_password" {
  source = "../modules/secret"

  secret_id  = "db-password"
  project_id = "my-secrets-project"
  labels     = { app = "backend", env = "prod" }

  replica_locations = ["asia-southeast2"]

  rotation_period     = "2592000s" # 30 days
  next_rotation_time  = "2026-08-01T00:00:00Z"
  notification_topics = ["projects/my-secrets-project/topics/secret-rotation-events"]

  accessors      = ["serviceAccount:app@my-secrets-project.iam.gserviceaccount.com"]
  version_adders = ["serviceAccount:rotation-bot@my-secrets-project.iam.gserviceaccount.com"]
}
```

## Inputs

| Name | Type | Default | Required |
| --- | --- | --- | :---: |
| `secret_id` | `string` | – | yes |
| `project_id` | `string` | – | yes |
| `labels` | `map(string)` | `{}` | no |
| `replica_locations` | `list(string)` | `[]` (automatic) | no |
| `kms_key_name` | `string` | `null` | no |
| `ttl` | `string` | `null` | no |
| `rotation_period` | `string` | `null` | no |
| `next_rotation_time` | `string` | `null` | no |
| `notification_topics` | `list(string)` | `[]` | no |
| `accessors` | `list(string)` | `[]` | no |
| `version_adders` | `list(string)` | `[]` | no |
| `admins` | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| --- | --- |
| `id` | Full resource ID (`projects/../secrets/..`) |
| `name` | Resource name |
| `secret_id` | Short secret ID |
