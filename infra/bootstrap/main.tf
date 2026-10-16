locals {
  labels = {
    app        = "tramites"
    env        = "dev"
    owner      = var.owner
    managed-by = "terraform"
  }

  apis = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudkms.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "billingbudgets.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com", # notification channel for the budget alerts
    "storage.googleapis.com",    # state bucket
  ]
}

# Reading the project needs the Cloud Resource Manager API, which this same root enables.
# depends_on defers the read to apply time, after the APIs exist.
data "google_project" "this" {
  project_id = var.project_id

  depends_on = [google_project_service.apis]
}

# Keeping the APIs enabled on destroy avoids breaking anything else in the project
# and the "disable" call is slow and flaky.
resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Remote state for infra/platform. This root keeps its own state locally (chicken-and-egg:
# the bucket cannot store the state of the code that creates it).
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.region
  labels   = local.labels

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Lets `terraform destroy` remove the bucket even though it holds state versions.
  # Acceptable for a disposable lab, not for production state.
  force_destroy = true

  versioning {
    enabled = true
  }

  # Versioning keeps every old state forever unless old versions are pruned.
  lifecycle_rule {
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_monitoring_notification_channel" "budget_email" {
  display_name = "Budget alerts"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.apis]
}

# A budget only notifies: it does NOT stop spending when the limit is reached.
resource "google_billing_budget" "this" {
  billing_account = var.billing_account_id
  display_name    = "${var.project_id}-budget"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.9
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  # Forecast: warns before the money is spent if the trend will exceed the budget.
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.budget_email.id]
    disable_default_iam_recipients   = false
  }

  depends_on = [google_project_service.apis]
}
