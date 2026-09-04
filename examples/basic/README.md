# Basic example (module development / CI)

This directory is **not** a production starter. It exists so we can `terraform apply` the module
from a local checkout (GitHub Actions and local iteration).

- `source = "../../"` tests the code in this repo, not a published version.
- `backend "local"` keeps CI state on the runner. **Do not use a local backend in
  production.**

Customer-facing usage (Terraform Registry source, your own providers and remote state) is in:

- the [root README](../../README.md)
- [examples/basic-remote](../basic-remote/)

## Usage for Development

Within `examples/basic/` (eg, here), create a `terraform.tfvars` file with the following content,
customizing AWS account id and Worklytics Tenant ID as needed.

Omit `existing_s3_bucket_names` (or pass `[]`) to have the module create a bucket; set it to reuse one.

```hcl
worklytics_tenant_id = "123456712345671234567"
aws_account_id       = "626567183302" # our CI account; use your own!
# aws_role_name      = "Admin"        # optional; omit if already auth'd
# existing_s3_bucket_names = ["my-existing-ingest-bucket"]
resource_name_prefix = "my-worklytics-data-import-" # Optional
```

Then test the example:

```shell
terraform init
terraform apply
```
