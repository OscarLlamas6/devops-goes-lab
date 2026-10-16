resource "google_cloud_run_v2_service" "tramites_api" {
  name                = local.service_name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false
  labels              = local.labels

  dynamic "binary_authorization" {
    for_each = var.enable_binauthz ? [1] : []

    content {
      use_default = true
    }
  }

  template {
    service_account                  = google_service_account.runtime.email
    timeout                          = "10s"
    max_instance_request_concurrency = 80
    labels                           = local.labels

    # Scale to zero when idle. max_instance_count is the hard ceiling on spending.
    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      image = local.placeholder_image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true # CPU is only allocated while a request is being served
      }

      env {
        name = "API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.api_key.secret_id
            version = var.api_key_secret_version
          }
        }
      }

      startup_probe {
        http_get {
          path = "/health"
        }
        period_seconds    = 2
        timeout_seconds   = 1
        failure_threshold = 10
      }

      liveness_probe {
        http_get {
          path = "/health"
        }
        period_seconds    = 30
        timeout_seconds   = 2
        failure_threshold = 3
      }
    }
  }

  # Terraform owns the platform; the pipeline owns the image. Ignoring these attributes stops
  # a `terraform apply` from rolling the service back to the placeholder after a deploy.
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  # The revision cannot start unless the runtime SA can already read the secret version.
  depends_on = [google_secret_manager_secret_iam_member.runtime_reads_api_key]
}

# Public service for citizens: anyone can invoke it. Authentication is not a citizen concern here.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  location = google_cloud_run_v2_service.tramites_api.location
  name     = google_cloud_run_v2_service.tramites_api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
