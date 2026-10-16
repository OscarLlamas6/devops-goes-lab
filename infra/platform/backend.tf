# Remote state in the bucket created by infra/bootstrap. The bucket name is passed at init:
#   terraform init -backend-config="bucket=<project_id>-tfstate"
terraform {
  backend "gcs" {
    prefix = "platform"
  }
}
