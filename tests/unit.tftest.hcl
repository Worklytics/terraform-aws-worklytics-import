# Functional unit tests. Mocked AWS provider; no cloud credentials required.
# Requires Terraform >= 1.7 (`mock_provider`).

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
      id         = "aws"
    }
  }

  mock_data "aws_s3_bucket" {
    defaults = {
      id     = "existing-import-bucket"
      bucket = "existing-import-bucket"
      arn    = "arn:aws:s3:::existing-import-bucket"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id     = "worklytics-import-created"
      bucket = "worklytics-import-created"
      arn    = "arn:aws:s3:::worklytics-import-created"
    }
  }

  mock_resource "aws_s3_bucket_public_access_block" {
    defaults = {
      id = "worklytics-import-created"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      id   = "worklytics-import-Tenant"
      name = "worklytics-import-Tenant"
      arn  = "arn:aws:iam::123456789012:role/worklytics-import-Tenant"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      id   = "worklytics-import-TenantBucketAccess"
      name = "worklytics-import-TenantBucketAccess"
      arn  = "arn:aws:iam::123456789012:policy/worklytics-import-TenantBucketAccess"
    }
  }

  mock_resource "aws_iam_role_policy_attachment" {
    defaults = {
      id = "worklytics-import-Tenant/worklytics-import-TenantBucketAccess"
    }
  }
}

mock_provider "local" {}

variables {
  worklytics_tenant_id = "123456789012345678901"
  todos_as_local_files = false
}

run "creates_bucket_when_omitted" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket.worklytics_import) == 1
    error_message = "Expected an S3 bucket to be created when s3_bucket_name is omitted."
  }

  assert {
    condition     = length(aws_s3_bucket_public_access_block.worklytics_import) == 1
    error_message = "Expected a public access block on the created bucket."
  }

  assert {
    condition     = jsondecode(aws_iam_role.for_worklytics_tenant.assume_role_policy).Statement.Condition.StringEquals["accounts.google.com:aud"] == var.worklytics_tenant_id
    error_message = "Role trust policy aud condition must be the Worklytics tenant numeric ID."
  }

  assert {
    condition     = jsondecode(aws_iam_role.for_worklytics_tenant.assume_role_policy).Statement.Principal.Federated == "accounts.google.com"
    error_message = "Role trust policy must federate Google accounts."
  }
}

run "versioning_and_logging_off_by_default" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket.worklytics_import[0].versioning) == 0
    error_message = "Versioning must be off by default on a created bucket."
  }

  assert {
    condition     = length(aws_s3_bucket.worklytics_import[0].logging) == 0
    error_message = "Access logging must be off by default on a created bucket."
  }
}

run "versioning_opt_in_on_created_bucket" {
  command = plan

  variables {
    enable_aws_s3_bucket_versioning = true
  }

  assert {
    condition     = aws_s3_bucket.worklytics_import[0].versioning[0].enabled == true
    error_message = "enable_aws_s3_bucket_versioning = true should enable versioning on a created bucket."
  }
}

run "reuses_existing_bucket" {
  command = plan

  variables {
    s3_bucket_name = "existing-import-bucket"
  }

  assert {
    condition     = length(aws_s3_bucket.worklytics_import) == 0
    error_message = "Should not create a bucket when s3_bucket_name is provided."
  }

  assert {
    condition     = length(aws_s3_bucket_public_access_block.worklytics_import) == 0
    error_message = "Should not modify public access on an existing bucket."
  }

  assert {
    condition     = output.s3_bucket_id == "existing-import-bucket"
    error_message = "Output bucket id should match the provided existing bucket."
  }

  assert {
    condition     = length(data.aws_s3_bucket.existing) == 1
    error_message = "Should look up the existing bucket."
  }

  # Policy document is known at plan only when bucket names are inputs (not bucket_prefix).
  assert {
    condition = contains(
      jsondecode(aws_iam_policy.allow_worklytics_tenant_bucket_access.policy).Statement[0].Action,
      "s3:ListBucket"
    )
    error_message = "Worklytics must be granted s3:ListBucket on the import bucket."
  }

  assert {
    condition = alltrue([
      contains(jsondecode(aws_iam_policy.allow_worklytics_tenant_bucket_access.policy).Statement[1].Action, "s3:GetObject"),
      contains(jsondecode(aws_iam_policy.allow_worklytics_tenant_bucket_access.policy).Statement[1].Action, "s3:PutObject"),
      contains(jsondecode(aws_iam_policy.allow_worklytics_tenant_bucket_access.policy).Statement[1].Action, "s3:DeleteObject"),
    ])
    error_message = "Worklytics must be granted Get/Put/Delete object on the import bucket."
  }

  assert {
    condition = contains(
      jsondecode(aws_iam_policy.allow_worklytics_tenant_bucket_access.policy).Statement[0].Resource,
      "arn:aws:s3:::existing-import-bucket"
    )
    error_message = "ListBucket resource must be the existing bucket ARN."
  }
}

run "grants_access_to_additional_import_buckets" {
  command = plan

  variables {
    s3_bucket_name  = "existing-import-bucket"
    s3_bucket_names = ["second-ingest-bucket"]
  }

  assert {
    condition     = length(aws_s3_bucket.worklytics_import) == 0
    error_message = "Should not create a bucket when all import locations already exist."
  }

  assert {
    condition     = length(output.import_buckets) == 2
    error_message = "import_buckets output should include primary and the extra landing zone."
  }

  assert {
    condition     = length(jsondecode(aws_iam_policy.allow_worklytics_tenant_bucket_access.policy).Statement[0].Resource) == 2
    error_message = "ListBucket should be granted on both buckets."
  }
}

run "list_only_skips_created_primary" {
  command = plan

  variables {
    s3_bucket_names = ["only-from-list-bucket"]
  }

  assert {
    condition     = length(aws_s3_bucket.worklytics_import) == 0
    error_message = "List-only existing locations should not create a bucket."
  }

  assert {
    condition     = output.s3_bucket_id == "only-from-list-bucket"
    error_message = "Primary outputs should fall back to the listed bucket."
  }
}

run "rejects_non_numeric_tenant_id" {
  command = plan

  variables {
    worklytics_tenant_id = "not-a-numeric-id"
  }

  expect_failures = [
    var.worklytics_tenant_id,
  ]
}

run "rejects_short_tenant_id" {
  command = plan

  variables {
    worklytics_tenant_id = "1234567890"
  }

  expect_failures = [
    var.worklytics_tenant_id,
  ]
}

run "rejects_invalid_s3_bucket_name" {
  command = plan

  variables {
    s3_bucket_name = "NOT-VALID"
  }

  expect_failures = [
    var.s3_bucket_name,
  ]
}

run "rejects_invalid_s3_bucket_names_entry" {
  command = plan

  variables {
    s3_bucket_names = ["NOT-VALID"]
  }

  expect_failures = [
    var.s3_bucket_names,
  ]
}

run "todo_deep_links_use_prod_host" {
  command = apply

  variables {
    s3_bucket_name   = "existing-import-bucket"
    todos_as_outputs = true
  }

  assert {
    condition     = strcontains(output.todo_markdown, "https://app.worklytics.co/analytics/connect/s3-import?")
    error_message = "TODO deep link must use production app.worklytics.co and the s3-import connect route."
  }

  assert {
    condition     = !strcontains(output.todo_markdown, "worklytics-dev")
    error_message = "TODO URLs must not point at worklytics-dev (or similar) by default."
  }
}

run "todo_respects_custom_worklytics_host" {
  command = apply

  variables {
    s3_bucket_name   = "existing-import-bucket"
    todos_as_outputs = true
    worklytics_host  = "acme.worklytics.co"
  }

  assert {
    condition     = strcontains(output.todo_markdown, "https://acme.worklytics.co/analytics/connect/s3-import?")
    error_message = "TODO deep link must use the configured worklytics_host."
  }
}

run "rejects_worklytics_host_with_scheme" {
  command = plan

  variables {
    worklytics_host = "https://app.worklytics.co"
  }

  expect_failures = [
    var.worklytics_host,
  ]
}
