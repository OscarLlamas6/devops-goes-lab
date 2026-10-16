terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # The Budgets API rejects user credentials unless the call is billed to a project.
  user_project_override = true
  billing_project       = var.project_id
}
