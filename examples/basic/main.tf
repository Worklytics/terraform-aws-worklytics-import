# Development / CI example only. Customers should copy from the root README or
# examples/basic-remote/ (Terraform Registry source), not this relative path.

terraform {
  # Local state is convenient for iterating on this repo and for GitHub Actions e2e.
  # Do NOT use a local backend in production; use remote state (Terraform Cloud, S3,
  # GCS, etc.) so state is shared, locked, and backed up.
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Provider version constraints live in aws_provider_version_test.tf so the
# integration workflow can overwrite that file to pin AWS provider majors. A
# second required_providers block here would fail terraform init.

# In real use you likely already have an AWS provider block in the root module.
provider "aws" {
  assume_role {
    role_arn = var.aws_role_name == null ? null : "arn:aws:iam::${var.aws_account_id}:role/${var.aws_role_name}"
  }

  allowed_account_ids = [
    var.aws_account_id
  ]
}

module "worklytics_import" {
  # Relative source so CI tests *this* checkout. Published usage:
  #   source  = "Worklytics/worklytics-import/aws"
  #   version = "~> 0.1.0"
  source = "../../"

  resource_name_prefix                     = var.resource_name_prefix
  worklytics_tenant_id                     = var.worklytics_tenant_id
  worklytics_tenant_sa_email               = var.worklytics_tenant_sa_email
  s3_bucket_name                           = var.s3_bucket_name
  s3_bucket_names                          = var.s3_bucket_names
  enable_aws_s3_bucket_public_access_block = var.enable_aws_s3_bucket_public_access_block
  todos_as_local_files                     = var.todos_as_local_files
}

output "s3_bucket_id" {
  value = module.worklytics_import.s3_bucket_id
}

output "s3_bucket_arn" {
  value = module.worklytics_import.s3_bucket_arn
}

output "import_buckets" {
  value = module.worklytics_import.import_buckets
}

output "worklytics_tenant_aws_role_arn" {
  value = module.worklytics_import.worklytics_tenant_aws_role.arn
}
