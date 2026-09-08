# example of consuming this module from the Terraform Registry once published

module "worklytics_import" {
  source  = "Worklytics/worklytics-import/aws"
  version = "~> 0.1.0"

  # numeric ID of your Worklytics Tenant SA (21-digit unique ID, not the email)
  worklytics_tenant_id = "123123123123123123123"

  # omit existing_s3_bucket_names (or pass []) to create a bucket in the provider region
  # existing_s3_bucket_names = ["my-existing-ingest-bucket"]
}

# Optional: remaining Worklytics console steps. Requires hashicorp/local in the root module.
resource "local_file" "todo" {
  filename = "TODO - configure import in worklytics.md"
  content  = module.worklytics_import.todo_markdown
}
