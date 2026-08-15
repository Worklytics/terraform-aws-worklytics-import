output "s3_bucket_id" {
  value       = local.primary_bucket_id
  description = "Name of the primary S3 bucket used as the import landing zone."
}

output "s3_bucket_arn" {
  value       = local.resolved_import_buckets[local.primary_bucket_id].arn
  description = "ARN of the primary S3 bucket used as the import landing zone."
}

output "worklytics_import_bucket" {
  value       = local.create_bucket ? aws_s3_bucket.worklytics_import[0] : null
  description = <<-EOT
    The Terraform resource created as the import bucket, or `null` if an existing bucket was
    provided. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket#attributes-reference
    for details. Useful to compose with `aws_s3_bucket_*` resources (lifecycle, encryption, etc.).
  EOT
}

output "import_buckets" {
  value       = local.resolved_import_buckets
  description = <<-EOT
    Map of all import landing zones keyed by bucket name. Each value has `id` and `arn`.
  EOT
}

output "worklytics_tenant_aws_role" {
  value       = aws_iam_role.for_worklytics_tenant
  description = <<-EOT
    The IAM role that your Worklytics Tenant will assume before operating on your AWS
    infrastructure. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#attributes-reference
    for details. Useful for composing with additional Terraform code, to support advanced
    deployment scenarios (e.g. KMS grants).
  EOT
}

output "todo_markdown" {
  value       = var.todos_as_outputs ? local.todo_content : null
  description = "Actions that must be performed outside of Terraform (markdown format)."
}
