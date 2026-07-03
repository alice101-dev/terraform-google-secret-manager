# Terraform — GCP Secret Manager

[![CI](https://github.com/alice101-dev/terraform-google-secret-manager/actions/workflows/ci.yml/badge.svg)](https://github.com/alice101-dev/terraform-google-secret-manager/actions/workflows/ci.yml)

Production-shaped secret management on GCP with
[Secret Manager](https://cloud.google.com/secret-manager/docs): per-secret
least-privilege IAM, rotation reminders over Pub/Sub, Data Access audit
logging — and **secret values that never touch the Terraform state**.

## What this provisions

| Secret | Replication | Rotation reminder | Access |
| --- | --- | --- | --- |
| `db-password` | user-managed (`asia-southeast2`) | every 30 days | backend SA (read), rotation bot (write-only) |
| `external-api-key` | automatic | every 90 days | backend SA (read) |
| `ci-webhook-secret` | automatic | — | CI runner SA (read), platform team (admin of this secret only) |

Plus:

- **Required APIs** enabled (Secret Manager, Pub/Sub, Logging).
- **Rotation topic** — Secret Manager publishes to `secret-rotation-events`
  when a secret hits its rotation schedule; the service agent is created and
  granted `pubsub.publisher` automatically.
- **Audit logging** — Data Access logs (`ADMIN_READ`/`DATA_READ`/`DATA_WRITE`)
  for `secretmanager.googleapis.com`, so every `AccessSecretVersion` call is
  recorded, and auditors get `roles/logging.privateLogViewer`.

## No secrets in state — the write-only pattern

The classic mistake with `google_secret_manager_secret_version` is passing
`secret_data`, which stores the **plaintext in the Terraform state file**.
This repo uses the write-only alternative (Terraform ≥ 1.11, provider ≥ 6.25):

```hcl
resource "google_secret_manager_secret_version" "bootstrap" {
  secret                 = module.secrets["db-password"].id
  secret_data_wo         = var.bootstrap_secret_values["db-password"] # ephemeral
  secret_data_wo_version = var.bootstrap_secret_wo_version
}
```

- `secret_data_wo` is **write-only**: sent to the API, never written to state
  or plan files.
- `var.bootstrap_secret_values` is an **ephemeral** variable: it exists in
  memory only for the duration of the run and is passed at apply time:

```bash
TF_VAR_bootstrap_secret_values='{"db-password":"s3cr3t"}' terraform apply
```

- To push a new value later, bump `bootstrap_secret_wo_version` — or skip
  Terraform entirely for day-2 rotation:

```bash
gcloud secrets versions add db-password --data-file=- <<< "$NEW_VALUE"
```

## Least-privilege IAM model

All grants are **per secret**, never project-wide:

| Role | Who | Why |
| --- | --- | --- |
| `secretmanager.secretAccessor` | workload SA | read the payload at runtime |
| `secretmanager.secretVersionAdder` | rotation automation | may add versions, cannot read them |
| `secretmanager.admin` (single secret) | owning team | manage settings for their secret only |

## Repository layout

```
.
├── .github/
│   └── workflows/
│       └── ci.yml             # fmt + validate + Checkov on every push/PR
├── modules/
│   └── secret/                # reusable secret wrapper (replication, CMEK, rotation, IAM)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
├── resources/                 # root config (the deployable stack)
│   ├── providers.tf           # google + google-beta >= 7.0, < 8.0
│   ├── main.tf                # APIs, rotation topic, secrets, bootstrap versions, audit logs
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars       # example values — edit before applying
│   └── backend.tf.example     # GCS remote-state template
├── .gitignore
└── README.md
```

## Prerequisites

- Terraform **>= 1.11** (write-only attributes + ephemeral variables).
- `hashicorp/google` and `hashicorp/google-beta` **>= 7.0, < 8.0**
  (google-beta is only used for `google_project_service_identity`).
- Credentials with rights to enable APIs, manage IAM, and create secrets
  (e.g. `roles/secretmanager.admin` + `roles/pubsub.admin` +
  `roles/serviceusage.serviceUsageAdmin`).

## Usage

```bash
cd resources

# 1. Edit terraform.tfvars — set project_id and your real SAs/groups.
# 2. (Optional) Enable remote state:
cp backend.tf.example backend.tf   # then edit the bucket name

terraform init
terraform plan
TF_VAR_bootstrap_secret_values='{"db-password":"<value>"}' terraform apply
```

## Rotation flow (day-2)

1. On schedule, Secret Manager publishes to the `secret-rotation-events` topic.
2. A subscriber (Cloud Run / Cloud Function / alerting) picks it up; the
   rotation bot generates a new credential and calls
   `gcloud secrets versions add` — allowed by `secretVersionAdder`, which
   cannot read existing versions.
3. Workloads read the new version at next fetch (`latest` alias) — access is
   recorded in the Data Access audit logs:

```
protoPayload.serviceName="secretmanager.googleapis.com"
protoPayload.methodName="google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion"
```

## Testing & security scanning

Every push and pull request runs through [GitHub Actions](.github/workflows/ci.yml):

```bash
terraform fmt -check -recursive          # formatting
terraform init -backend=false && terraform validate   # schema validation (in resources/)
checkov -d . --framework terraform       # static security analysis
```

Checkov: **0 failed** (one documented skip: CMEK on the rotation topic is
optional because its messages carry schedule metadata, never secret payloads —
set `rotation_topic_kms_key` to opt in).

## Related

- [terraform-gcp-pam](https://github.com/alice101-dev/terraform-gcp-pam-jit-access) —
  just-in-time, approval-gated `secretAccessor` elevation for humans; this repo
  covers the standing (workload) access side.
