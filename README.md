# Worklytics Import from AWS Terraform Module

[![Latest Release](https://img.shields.io/github/v/release/Worklytics/terraform-aws-worklytics-import)](https://github.com/Worklytics/terraform-aws-worklytics-import/releases/latest)
[![tests](https://img.shields.io/github/actions/workflow/status/Worklytics/terraform-aws-worklytics-import/terraform_integration.yaml?label=tests)](https://github.com/Worklytics/terraform-aws-worklytics-import/actions?query=branch%3Amain)

This module creates infra to support importing data from [Amazon S3] into Worklytics.

It is intended for **non-proxy** Worklytics customers (files or dumps in your AWS account that
Worklytics should pull). If you use Worklytics with a [Psoxy] proxy, do not use this module for
that path: the [proxy Terraform modules] already provide equivalent functionality for connecting
sanitized data to Worklytics.

It is intended for the [Terraform Registry](https://registry.terraform.io/modules/Worklytics/worklytics-import/aws/latest)
(`Worklytics/worklytics-import/aws`).

If it does not meet your needs, feel free to directly copy the `main.tf` file into your own Terraform
configuration and adapt it to your requirements.

## What it provisions

1. **Optional storage** — an S3 bucket, unless you pass an existing `s3_bucket_name` and/or
   `s3_bucket_names`. Additional ingest locations can be passed via the list.
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

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `worklytics_tenant_id` | yes | | 21-digit unique ID of the Worklytics tenant GCP SA |
| `s3_bucket_name` | no | `null` | Reuse this bucket as the primary zone; otherwise one is created if the list is also empty |
| `s3_bucket_names` | no | `[]` | Extra existing import landing zones |
| `worklytics_tenant_sa_email` | no | `null` | SA email, documentation only |
| `resource_name_prefix` | no | `worklytics-import-` | Prefix for created IAM / bucket names |
| `enable_aws_s3_bucket_public_access_block` | no | `true` | Restrictive public-access block on a *created* bucket |

Your Worklytics tenant identity is the **numeric unique ID** of the tenant's GCP service account
(the same value used by the AWS and Azure *export* modules). The SA email cannot be used as the
federated `aud` claim. Obtain the ID from the Worklytics app, or:

```bash
gcloud iam service-accounts describe EMAIL --format='value(uniqueId)'
```

## Outputs

#### `s3_bucket_id` / `s3_bucket_arn`
The primary S3 bucket used as the import landing zone (created or reused).

#### `worklytics_import_bucket`
The Terraform `aws_s3_bucket` resource when this module created the bucket; `null` if you passed
an existing name. Useful to compose with other `aws_s3_bucket_*` resources to configure retention,
encryption, etc. See:
  - [aws_s3_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration)
  - [aws_s3_bucket_server_side_encryption_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration)

#### `import_buckets`
Map of every import landing zone (the primary zone plus any `s3_bucket_names` inputs), keyed by
bucket name. Each value has `id` and `arn`.

#### `worklytics_tenant_aws_role`
The IAM role that your Worklytics Tenant will assume before operating on your AWS infrastructure.

Eg, Worklytics's infra will do the equivalent of
[`aws sts assume-role-with-web-identity`](https://docs.aws.amazon.com/cli/latest/reference/sts/assume-role-with-web-identity.html)
on this role, authenticated by GCP as the GCP Service Account you identified with
`worklytics_tenant_id`.

See [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
for the general idea; this is the reverse direction of that (GCP → AWS, rather than AWS → GCP).

This value is useful for a few scenarios:
  - if you set a CMEK to encrypt the bucket rather than relying on AWS default, you may need to
    grant encrypt / data key creation permissions to this role.
  - if your AWS account has additional IAM policies which would *deny* the permissions needed by
    this role for S3/etc, use this role's ARN to add exceptions to those policies
    (in AWS IAM logic, explicit deny has precedence over explicit allow)

#### `todo_markdown`
Rendered when `todos_as_outputs = true`.

## Compatibility

This module is meant for use with Terraform 1.1+ and AWS provider `>= 3.0`. If you find
incompatibilities using Terraform >= 1.1, please open an issue.

This module does not configure provider blocks; the caller must.

## Usage Tips

### Existing bucket

Pass a name to skip bucket creation and only grant Worklytics access:

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/aws"

  worklytics_tenant_id = "123456789012345678901"
  s3_bucket_name       = "my-existing-ingest-bucket"
}
```

### Multiple import buckets

Keep the singular variable for the primary landing zone and pass extra locations:

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/aws"

  worklytics_tenant_id = "123456789012345678901"
  s3_bucket_name       = "my-existing-ingest-bucket"
  s3_bucket_names = [
    "my-existing-hris-bucket",
    "my-existing-calendar-bucket",
  ]
}
```

If `s3_bucket_names` is set and `s3_bucket_name` is omitted, only the list is used (no extra
created primary).

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
