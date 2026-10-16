# Only the container of the secret is managed here. The value never goes through Terraform,
# otherwise it would sit in plain text in the state file. Load it with:
#   printf '%s' "$(openssl rand -hex 24)" | gcloud secrets versions add api-key --data-file=-
resource "google_secret_manager_secret" "api_key" {
  secret_id = "api-key"
  labels    = local.labels

  replication {
    auto {}
  }
}
