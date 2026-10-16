variable "project_id" {
  description = "GCP project that hosts everything."
  type        = string
}

variable "region" {
  description = "Region for Cloud Run, Artifact Registry and KMS."
  type        = string
  default     = "us-central1"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to deploy through Workload Identity Federation."
  type        = string
}

variable "owner" {
  description = "Value of the owner label."
  type        = string
}

variable "api_key_secret_version" {
  description = <<-EOT
    Version of the api-key secret mounted in Cloud Run. Pinned (not "latest") so a rotation is an
    explicit, reviewable change: new version, bump this value, apply. With "latest" the value would
    change silently on the next instance start and a bad secret could break running traffic.
  EOT
  type        = string
  default     = "1"
}

variable "enable_binauthz" {
  description = <<-EOT
    Create the Binary Authorization resources and make Cloud Run enforce the policy.
    Enabling it blocks any image without an attestation from the pipeline, so apply it only when
    the pipeline already signs images (see the deploy workflow).
  EOT
  type        = bool
  default     = true
}
