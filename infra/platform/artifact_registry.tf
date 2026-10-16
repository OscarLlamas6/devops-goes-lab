resource "google_artifact_registry_repository" "tramites" {
  location      = var.region
  repository_id = "tramites"
  format        = "DOCKER"
  description   = "Images of the tramites service"
  labels        = local.labels

  # A tag can never move to another image: what was scanned and attested is what runs.
  docker_config {
    immutable_tags = true
  }

  # Known limitation: with immutable tags, Artifact Registry does NOT let cleanup policies delete
  # tagged images, and every image the pipeline pushes is tagged with its commit SHA. So these
  # policies only ever remove untagged images; tagged ones accumulate (about 9 MB each, cents per
  # month). Immutability was kept on purpose over automatic cleanup. KEEP wins over DELETE.
  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-last-10"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-older-than-7d"
    action = "DELETE"

    condition {
      tag_state  = "ANY"
      older_than = "604800s"
    }
  }
}
