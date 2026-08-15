variable "resource_name_prefix" {
  type        = string
  description = "Prefix to give to names of infra created by this module, where applicable."
  default     = "worklytics-import-"
}

variable "worklytics_tenant_id" {
  type        = string
  description = <<-EOT
    Numeric unique ID of your Worklytics tenant's GCP service account (obtain from the Worklytics
    app). This is a 21-digit value used as the `aud` claim of the Google ID token that AWS
    validates when the tenant assumes the import role. It is the same identifier used by the
    AWS/Azure export modules; it is *not* the SA email.
  EOT

  validation {
    condition     = can(regex("^\\d{21}$", var.worklytics_tenant_id))
    error_message = "`worklytics_tenant_id` must be a 21-digit numeric value."
  }
}

variable "worklytics_tenant_sa_email" {
  type        = string
  description = <<-EOT
    Optional email of your Worklytics tenant's GCP service account. Used only in generated
    instructions; federation is keyed by `worklytics_tenant_id`.
  EOT
  default     = null
}

variable "s3_bucket_name" {
  type        = string
  description = <<-EOT
    Existing S3 bucket for the primary import landing zone. If null and `s3_bucket_names` is
    empty, a bucket is created. Providing a name skips bucket creation; the module only grants
    Worklytics access.
  EOT
  default     = null
  nullable    = true

  validation {
    condition     = var.s3_bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.s3_bucket_name))
    error_message = "`s3_bucket_name` must be a valid S3 bucket name (3-63 chars, lowercase letters, numbers, dots, hyphens)."
  }
}

variable "s3_bucket_names" {
  type        = list(string)
  description = <<-EOT
    Optional additional existing S3 buckets to grant Worklytics access to. Use this when the
    customer has several ingest locations. Singular `s3_bucket_name` still describes the primary
    zone. A bucket is created only when both this list and `s3_bucket_name` are empty.

    If this list is non-empty and `s3_bucket_name` is null, only the listed buckets are used
    (no extra created primary).
  EOT
  default     = []

  validation {
    condition = alltrue([
      for name in var.s3_bucket_names :
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", name))
    ])
    error_message = "Each `s3_bucket_names` entry must be a valid S3 bucket name."
  }
}

variable "enable_aws_s3_bucket_public_access_block" {
  type        = bool
  description = <<-EOT
    Whether to place a restrictive `aws_s3_bucket_public_access_block` on a bucket *created* by
    this module. Set to `false` if you wish to configure something equivalent outside this module.
    Existing buckets are never modified.
  EOT
  default     = true
}

variable "worklytics_host" {
  type        = string
  description = "Host of the Worklytics instance where the tenant resides (e.g. app.worklytics.co)."
  default     = "app.worklytics.co"
}

variable "todos_as_outputs" {
  type        = bool
  description = <<-EOT
    Whether to render TODOs as outputs (useful if you're using Terraform Cloud/Enterprise, or
    somewhere else where the filesystem is not readily accessible to you).
  EOT
  default     = false
}

variable "todos_as_local_files" {
  type        = bool
  description = "Whether to render TODOs as flat files."
  default     = true
}
