locals {
  service_name = "tramites-api"

  labels = {
    app        = "tramites"
    env        = "dev"
    owner      = var.owner
    managed-by = "terraform"
  }

  # Public image used only to create the service. The pipeline replaces it by digest.
  placeholder_image = "us-docker.pkg.dev/cloudrun/container/hello"
}
