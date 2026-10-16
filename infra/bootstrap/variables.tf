variable "project_id" {
  description = "GCP project that hosts everything."
  type        = string
}

variable "region" {
  description = "Region for the state bucket. us-central1 is a tier 1 region."
  type        = string
  default     = "us-central1"
}

variable "billing_account_id" {
  description = "Billing account that pays for the project (format XXXXXX-XXXXXX-XXXXXX)."
  type        = string
}

variable "alert_email" {
  description = "Email that receives the budget alerts."
  type        = string
}

variable "owner" {
  description = "Value of the owner label."
  type        = string
}

variable "budget_amount_usd" {
  description = "Monthly budget in USD. It alerts, it does not cap spending."
  type        = number
  default     = 10
}
