output "tfstate_bucket" {
  description = "Bucket that stores the remote state of infra/platform."
  value       = google_storage_bucket.tfstate.name
}

output "project_number" {
  description = "Numeric id of the project."
  value       = data.google_project.this.number
}

output "budget_name" {
  description = "Full resource name of the budget."
  value       = google_billing_budget.this.name
}
