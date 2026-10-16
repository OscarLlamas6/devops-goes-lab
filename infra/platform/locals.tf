locals {
  service_name = "tramites-api"

  labels = {
    app        = "tramites"
    env        = "dev"
    owner      = var.owner
    managed-by = "terraform"
  }

  # Public image used only to create the service. The pipeline replaces it by digest.
  # Pinned by digest because an untagged reference would resolve to :latest.
  placeholder_image = "us-docker.pkg.dev/cloudrun/container/hello@sha256:e2a01cf1e784fcc57c558ed2b1d1f76456de90771c0ad99ae3b6f57722c7dbf3"
}
