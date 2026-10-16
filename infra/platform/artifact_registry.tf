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

  # Image storage is the silent cost that grows. KEEP wins over DELETE, so the 10 most
  # recent versions always survive and anything older than 7 days beyond those is removed.
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
