# Worklytics Import from AWS Terraform Module

[![Latest Release](https://img.shields.io/github/v/release/Worklytics/terraform-aws-worklytics-import)](https://github.com/Worklytics/terraform-aws-worklytics-import/releases/latest)
[![tests](https://img.shields.io/github/actions/workflow/status/Worklytics/terraform-aws-worklytics-import/terraform_integration.yaml?label=tests)](https://github.com/Worklytics/terraform-aws-worklytics-import/actions?query=branch%3Amain)

This module creates infra to support **importing** data from [Amazon S3] into Worklytics
(customer premises → Worklytics). It does **not** set up the reverse path.

| Data flow | Module |
|-----------|--------|
| Customer premises → Worklytics | this module (`Worklytics/worklytics-import/aws`) |
| Worklytics → customer premises | [`terraform-aws-worklytics-export`](https://github.com/Worklytics/terraform-aws-worklytics-export) (`Worklytics/worklytics-export/aws`) |

Use the export module if Worklytics should write results or dumps into your account. Do not
compose this import module as a stand-in for that.

It is intended for **non-proxy** Worklytics customers (files or dumps in your AWS account that
Worklytics should pull). If you use Worklytics with a [Psoxy] proxy, do not use this module for
that path: the [proxy Terraform modules] already provide equivalent functionality for connecting
sanitized data to Worklytics.

It is intended for the [Terraform Registry](https://registry.terraform.io/modules/Worklytics/worklytics-import/aws/latest)
(`Worklytics/worklytics-import/aws`).

If it does not meet your needs, feel free to directly copy the `main.tf` file into your own Terraform
configuration and adapt it to your requirements.

## What it provisions

1. **Optional storage** — an S3 bucket, unless you pass `existing_s3_bucket_names`. Null or empty
   creates one bucket; a non-empty list only grants access (no bucket is created).
2. **IAM role** whose trust policy allows your Worklytics tenant's GCP service account to
   `AssumeRoleWithWebIdentity` (`issuer` / federated principal `accounts.google.com`,
   `aud` = `worklytics_tenant_id`).
3. **IAM policy** so that identity can list the bucket(s) and read/write/delete objects (ingest +
   checkpoints).

Worklytics then exchanges a Google ID token for AWS credentials and pulls objects from the
bucket (and may write ingest checkpoints).

A created bucket is placed in the region of the `aws` provider. Existing buckets are looked up by
name (S3 names are global).

## Usage

from Terraform registry (once published):
```hcl
module "worklytics-import" {
  source  = "Worklytics/worklytics-import/aws"
  version = "~> 0.1.0"

  # numeric ID of your Worklytics Tenant SA (21-digit unique ID, not the email)
  worklytics_tenant_id = "123456789012345678901"
}
```

via GitHub:
```hcl
module "worklytics-import" {
  source = "git::https://github.com/worklytics/terraform-aws-worklytics-import/?ref=v0.1.0"

  worklytics_tenant_id = "123456789012345678901"
}
```

The calling configuration must declare an `aws` provider. This module does not configure providers
(so it can be composed into an existing AWS workspace).

```hcl
provider "aws" {
  region = "us-west-2"
}
```

Your Worklytics tenant identity is the **numeric unique ID** of the tenant's GCP service account
(the same 21-digit value used by other Worklytics Terraform modules). The SA email cannot be used
as the federated `aud` claim. Obtain the ID from the Worklytics app, or:

```bash
gcloud iam service-accounts describe EMAIL --format='value(uniqueId)'
```

## Compatibility

This module is meant for use with Terraform 1.1+ and AWS provider `>= 3.0`. If you find
incompatibilities using Terraform >= 1.1, please open an issue.

This module does not configure provider blocks; the caller must.

## Usage Tips

### Existing bucket

Pass names to skip bucket creation and only grant Worklytics access:

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/aws"

  worklytics_tenant_id     = "123456789012345678901"
  existing_s3_bucket_names = ["my-existing-ingest-bucket"]
}
```

### Custom Worklytics domain

Connection TODO URLs default to production `https://app.worklytics.co/analytics/connect/s3-import`.
If the tenant lives on another hostname, set `worklytics_host` (hostname only, no `https://`):

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/aws"

  worklytics_tenant_id = "123456789012345678901"
  worklytics_host      = "acme.worklytics.co"
}
```

### Multiple import buckets

Pass every existing landing zone in one list. A non-empty list never creates a bucket:

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/aws"

  worklytics_tenant_id = "123456789012345678901"
  existing_s3_bucket_names = [
    "my-existing-ingest-bucket",
    "my-existing-hris-bucket",
    "my-existing-calendar-bucket",
  ]
}
```

### Customize Public Access Block

By default, we set a restrictive public access block on a *created* bucket. If you need something
more permissive, set `enable_aws_s3_bucket_public_access_block = false` and add your own:

```hcl
resource "aws_s3_bucket_public_access_block" "worklytics_import" {
  bucket = module.worklytics_import.s3_bucket_id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

Existing buckets are never modified.

### Role composition

Worklytics's infra does the equivalent of
[`aws sts assume-role-with-web-identity`](https://docs.aws.amazon.com/cli/latest/reference/sts/assume-role-with-web-identity.html)
on `worklytics_tenant_aws_role`, authenticated by GCP as the tenant SA identified with
`worklytics_tenant_id`. See [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
for the general idea. Authentication is GCP → AWS; the *data* flow is still customer S3 →
Worklytics.

Use the role output to:
  - grant encrypt / data-key permissions if you use a CMEK instead of AWS default encryption
  - add exceptions to account-level deny policies (explicit deny wins over allow)

Compose lifecycle or encryption against `s3_bucket_id` / `worklytics_import_bucket` when this
module created the bucket. See:
  - [aws_s3_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration)
  - [aws_s3_bucket_server_side_encryption_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration)

The `todo_markdown` output is always the remaining Worklytics console steps. Write it to a file
from your root module if you want a local TODO (see [examples/basic-remote](examples/basic-remote/)).

### Enable Bucket Versioning

Versioning is off by default on a *created* bucket. Enable it via:

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/aws"

  worklytics_tenant_id            = "123456789012345678901"
  enable_aws_s3_bucket_versioning = true
}
```

Or configure `aws_s3_bucket_versioning` yourself against `module.worklytics_import.s3_bucket_id`.

### Enable Access Logging

Pass an existing logging destination bucket (and optional prefix) to wire up server access logs
on a *created* bucket:

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/aws"

  worklytics_tenant_id     = "123456789012345678901"
  aws_s3_access_log_bucket = aws_s3_bucket.access_logs.id
  aws_s3_access_log_prefix = "worklytics-import/"
}
```

If omitted, you can still attach `aws_s3_bucket_logging` yourself using the module's bucket output.

### Add a Max Retention Policy

It's good practice to have a max retention policy on your bucket, even if it's really long. If you
have a data pipeline regularly depositing data here for Worklytics to pull, a value of 30 or 60
days after successful ingest can lower storage costs.

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "worklytics_import" {
  bucket = module.worklytics_import.s3_bucket_id

  rule {
    id      = "max_retention_5_years"
    enabled = true

    expiration {
      days = 5 * 365 # 5 years
    }
  }
}
```

### Permissions granted to Worklytics

| Action | Scope | Why |
|--------|-------|-----|
| `s3:ListBucket` | bucket | Enumerate objects to ingest |
| `s3:GetObject` | objects | Read ingest files |
| `s3:PutObject` / `s3:DeleteObject` | objects | Write/rotate ingest checkpoints |

The role trust policy allows Google (`accounts.google.com`) as federated principal and requires
`accounts.google.com:aud` to equal your `worklytics_tenant_id`.

If an existing bucket has a bucket policy that denies principals other than an explicit allow-list,
add this module's `worklytics_tenant_aws_role.arn` to that list.

## Development

This module is written and maintained by [Worklytics, Co.](https://worklytics.co/) and intended to
guide our customers in setting up their own infra to import data from Amazon S3 into Worklytics.

As this is [published as a Terraform module](https://developer.hashicorp.com/terraform/registry/modules/publish),
we will strive to follow [standard Terraform module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
and [style conventions](https://developer.hashicorp.com/terraform/language/syntax/style).

See [examples/basic/](examples/basic/) for a simple example of how to use this module.

### Releasing

Registry versions are **git tags** (`vX.Y.Z`) on `main`, not GitHub Releases. After a change is on
`main` and CI is green:

```bash
./tools/release.sh v0.1.0 --wait
```

That tags the current `origin/main` commit and pushes the tag. The tag-triggered workflow creates
the GitHub Release (notes / README badge). First-time listing on
[registry.terraform.io](https://registry.terraform.io/modules/Worklytics/worklytics-import/aws)
is a one-time Publish in the HashiCorp UI (`Worklytics/worklytics-import/aws`); later tags are
picked up by the Registry webhook.

### Tests

| Workflow | What it covers |
|----------|----------------|
| `terraform_lint.yaml` | `terraform fmt -check` |
| `terraform_validate.yaml` | `terraform init` / `validate` on `examples/basic`, plus `terraform test` unit tests |
| `terraform_integration.yaml` | Apply in a CI AWS account, then read/write an object as the stand-in Worklytics GCP identity |
| `terraform_security.yaml` | Trivy IaC scan |

Unit tests live in [`tests/`](tests/) and use Terraform's native test framework with a mocked
`aws` provider (no cloud credentials). Requires Terraform >= 1.7 (`mock_provider`).

Integration tests authenticate to **AWS** (GitHub → IAM OIDC) to apply this module, and to
**GCP** (GitHub → WIF) to impersonate the stand-in Worklytics tenant SA. The test then calls
`AssumeRoleWithWebIdentity` and PUTs/GETs an object. Required GitHub secrets (public repo) or
variables (private repo):

| Name | Purpose |
|------|---------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | GitHub Actions WIF provider |
| `GCP_SERVICE_ACCOUNT` | CI agent SA (e.g. `gh-actions-tf-aws-import@...`) |

The CI agent SA must be able to impersonate the stand-in tenant SA
(`w8s-import-tf-ci@worklytics-ci.iam.gserviceaccount.com`). GitHub OIDC must be able to assume
`arn:aws:iam::626567183302:role/gh_action_ci_agent_import` in the shared CI AWS account (same
sandbox as `terraform-aws-worklytics-export`; a *separate* role so this public repo cannot assume
the export CI role). That role is provisioned by `worklytics-infra` (`src/development`).

(c) 2026 Worklytics, Co

[Amazon S3]: https://docs.aws.amazon.com/s3/
[Psoxy]: https://github.com/Worklytics/psoxy
[proxy Terraform modules]: https://github.com/Worklytics/psoxy
