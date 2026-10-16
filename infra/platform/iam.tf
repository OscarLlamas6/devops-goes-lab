# One service account per responsibility.

resource "google_service_account" "runtime" {
  account_id   = "sa-runtime"
  display_name = "Cloud Run runtime identity"
  description  = "Identity of the tramites-api service. Can only read the api-key secret."
}

resource "google_service_account" "deployer" {
  account_id   = "sa-deployer"
  display_name = "CI/CD deployer identity"
  description  = "Impersonated by GitHub Actions through Workload Identity Federation."
}

# --- sa-runtime: read the secret, on that secret only (resource level, not project) ---

resource "google_secret_manager_secret_iam_member" "runtime_reads_api_key" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

# --- sa-deployer: push images, deploy the one service, act as the runtime SA ---

resource "google_artifact_registry_repository_iam_member" "deployer_pushes_images" {
  location   = google_artifact_registry_repository.tramites.location
  repository = google_artifact_registry_repository.tramites.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_cloud_run_v2_service_iam_member" "deployer_deploys_service" {
  location = google_cloud_run_v2_service.tramites_api.location
  name     = google_cloud_run_v2_service.tramites_api.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

# Deploying a revision that runs as sa-runtime requires permission to "act as" it.
# Granted on that single service account, not on the project.
resource "google_service_account_iam_member" "deployer_acts_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}
