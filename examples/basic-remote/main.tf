# example of consuming this module from the Terraform Registry once published

module "worklytics-import" {
  source  = "Worklytics/worklytics-import/aws"
  version = "~> 0.1.0"

  # numeric ID of your Worklytics Tenant SA (21-digit unique ID, not the email)
  worklytics_tenant_id = "123123123123123123123"

  # omit s3_bucket_name to create a bucket in the provider region
  # s3_bucket_name = "my-existing-ingest-bucket"
}
