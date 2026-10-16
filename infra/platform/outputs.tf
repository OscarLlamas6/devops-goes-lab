# These values are loaded as GitHub repository Variables (not Secrets: none of them is sensitive).

output "service_url" {
  description = "Public URL of the Cloud Run service."
  value       = google_cloud_run_v2_service.tramites_api.uri
}

output "wif_provider" {
  description = "Full name of the Workload Identity provider, for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_account" {
  description = "Email of the service account the pipeline impersonates."
  value       = google_service_account.deployer.email
}

output "artifact_registry_repo" {
  description = "Docker repository path, without image name or tag."
  value       = "${google_artifact_registry_repository.tramites.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.tramites.repository_id}"
}

output "attestor_name" {
  description = "Full attestor name (empty while Binary Authorization is disabled)."
  value       = try(google_binary_authorization_attestor.pipeline[0].id, "")
}

output "kms_key_version" {
  description = "Full KMS key version used to sign attestations (empty while disabled)."
  value       = try(replace(data.google_kms_crypto_key_version.attestor[0].id, "//cloudkms.googleapis.com/v1/", ""), "")
}
