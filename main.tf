data "aws_partition" "current" {}

locals {
  existing_bucket_names = distinct(compact(coalesce(var.existing_s3_bucket_names, [])))
  create_bucket         = length(local.existing_bucket_names) == 0
}

# Existence check: plan fails if a provided bucket name does not exist. IAM policy
# ARNs are constructed from the names (known at plan) rather than these data
# sources, so `bucket_prefix` creates and mocked tests stay consistent.
data "aws_s3_bucket" "existing" {
  for_each = toset(local.existing_bucket_names)

  bucket = each.value
}

# Trivy (as of 2026): AVD-AWS-0090 versioning / AVD-AWS-0089 access logging.
# Both are opt-in on a *created* bucket and off by default so this module stays a
# thin landing zone; pass enable_aws_s3_bucket_versioning / aws_s3_access_log_bucket
# or compose against worklytics_import_bucket. Nested blocks (not standalone
# resources) so AWS provider 3.x still validates.
#trivy:ignore:AVD-AWS-0090 versioning is opt-in via enable_aws_s3_bucket_versioning
#trivy:ignore:AVD-AWS-0089 access logging is opt-in via aws_s3_access_log_bucket
resource "aws_s3_bucket" "worklytics_import" {
  count = local.create_bucket ? 1 : 0

  bucket_prefix = replace(lower(var.resource_name_prefix), "_", "-")

  dynamic "versioning" {
    for_each = var.enable_aws_s3_bucket_versioning ? [true] : []
    content {
      enabled = true
    }
  }

  dynamic "logging" {
    for_each = var.aws_s3_access_log_bucket != null ? [var.aws_s3_access_log_bucket] : []
    content {
      target_bucket = logging.value
      target_prefix = var.aws_s3_access_log_prefix
    }
  }

  lifecycle {
    ignore_changes = [
      # don't conflict with tags customers might wish to add themselves
      tags,
    ]
  }
}

# set `enable_aws_s3_bucket_public_access_block = false` to disable this; if you do,
# we recommend configuring an equivalent block outside this module
resource "aws_s3_bucket_public_access_block" "worklytics_import" {
  count = local.create_bucket && var.enable_aws_s3_bucket_public_access_block ? 1 : 0

  bucket = aws_s3_bucket.worklytics_import[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  all_bucket_ids = concat(
    local.create_bucket ? [aws_s3_bucket.worklytics_import[0].id] : [],
    local.existing_bucket_names
  )

  primary_bucket_id = local.all_bucket_ids[0]

  bucket_arns = [
    for id in local.all_bucket_ids :
    "arn:${data.aws_partition.current.partition}:s3:::${id}"
  ]

  object_arns = [
    for id in local.all_bucket_ids :
    "arn:${data.aws_partition.current.partition}:s3:::${id}/*"
  ]

  resolved_import_buckets = {
    for id in local.all_bucket_ids : id => {
      id  = id
      arn = "arn:${data.aws_partition.current.partition}:s3:::${id}"
    }
  }
}

resource "aws_iam_role" "for_worklytics_tenant" {
  name = "${var.resource_name_prefix}Tenant"

  # Google is a first-class AWS IdP (`Federated = "accounts.google.com"`). Bind the
  # tenant SA unique ID on `sub` (same name in IAM and the JWT). Export historically
  # uses `aud`, which for these tokens is JWT `azp` — the same unique ID, worse name.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid    = "AllowWorklyticsTenantToAssumeRole"
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = "accounts.google.com"
      }
      Condition = {
        StringEquals = {
          "accounts.google.com:sub" = var.worklytics_tenant_id
        }
      }
    }
  })
}

# TODO if customer-managed KMS key, need perm to "kms:GenerateDataKey" and "kms:Decrypt".
# Leave that to the customer via composing with `worklytics_tenant_aws_role`; pretty common
# but key-specific.

resource "aws_iam_policy" "allow_worklytics_tenant_bucket_access" {
  name = "${var.resource_name_prefix}TenantBucketAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "WorklyticsTenantAccessImportBuckets"
    Statement = [
      {
        Sid    = "AllowWorklyticsTenantListImportBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
        ]
        Resource = local.bucket_arns
      },
      {
        Sid    = "AllowWorklyticsTenantObjectAccess"
        Effect = "Allow"
        Action = [
          # ingest: read customer objects
          "s3:GetObject",
          # checkpoints / status objects Worklytics may write back
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = local.object_arns
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "allow_worklytics_tenant_bucket_access" {
  role       = aws_iam_role.for_worklytics_tenant.name
  policy_arn = aws_iam_policy.allow_worklytics_tenant_bucket_access.arn
}

locals {
  import_todo_rows = join("\n", [
    for id in local.all_bucket_ids : "  - `${id}`"
  ])

  # App route is /analytics/connect/:integrationId; query keys match connection setting ids.
  s3_import_connect_url = join("", [
    "https://${var.worklytics_host}/analytics/connect/s3-import",
    "?bucket=${urlencode(local.primary_bucket_id)}",
    "&roleArn=${urlencode(aws_iam_role.for_worklytics_tenant.arn)}",
  ])

  todo_content = <<EOT
# Configure Data Import in Worklytics

1. Ensure you're authenticated with Worklytics. Either sign-in at [https://${var.worklytics_host}](https://${var.worklytics_host}) with your organization's SSO provider *or* request OTP link from your Worklytics support.
2. Visit [${local.s3_import_connect_url}](${local.s3_import_connect_url})
3. Review any additional settings and click "Create Data Import". Repeat for any extra buckets.

Import landing zones granted to Worklytics:
${local.import_todo_rows}

Alternatively, you may follow the manual instructions below:

1. Visit [https://${var.worklytics_host}/analytics/connect](https://${var.worklytics_host}/analytics/connect) (or log in to Worklytics and navigate to Connect → Amazon S3 Import).
2. Create a new Amazon S3 import connection with the following values:
  - Bucket: ${local.primary_bucket_id}
  - Role ARN: ${aws_iam_role.for_worklytics_tenant.arn}
  - Worklytics tenant identity: ${var.worklytics_tenant_id}

Write objects you want Worklytics to ingest into the bucket(s). Worklytics authenticates to AWS via `AssumeRoleWithWebIdentity` as the GCP service account above, then reads (and may write ingest checkpoints to) those buckets.
EOT
}
