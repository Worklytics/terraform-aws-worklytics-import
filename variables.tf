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
    validates when the tenant assumes the import role. It is *not* the SA email. This module
    only grants import access (customer S3 → Worklytics).
  EOT

  validation {
    condition     = can(regex("^\\d{21}$", var.worklytics_tenant_id))
    error_message = "`worklytics_tenant_id` must be a 21-digit numeric value."
  }
}

variable "existing_s3_bucket_names" {
  type        = list(string)
  description = <<-EOT
    Existing S3 buckets to grant Worklytics access to. Null or empty creates one bucket in the
    provider region; otherwise the module only grants access (no bucket is created).
  EOT
  default     = []
  nullable    = true

  validation {
    condition = var.existing_s3_bucket_names == null || alltrue([
      for name in var.existing_s3_bucket_names :
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", name))
    ])
    error_message = "Each `existing_s3_bucket_names` entry must be a valid S3 bucket name."
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

variable "enable_aws_s3_bucket_versioning" {
  type        = bool
  description = <<-EOT
    Whether to enable versioning on a bucket *created* by this module. Off by default; set true
    to opt in, or compose `aws_s3_bucket_versioning` yourself using the bucket output. Existing
    buckets are never modified.
  EOT
  default     = false
}

variable "aws_s3_access_log_bucket" {
  type        = string
  description = <<-EOT
    Optional destination bucket for server access logs of a *created* import bucket. When null,
    logging is not configured (compose `aws_s3_bucket_logging` yourself if needed). Existing
    buckets are never modified.
  EOT
  default     = null
  nullable    = true
}

variable "aws_s3_access_log_prefix" {
  type        = string
  description = "Prefix for S3 server access log keys. Only used when `aws_s3_access_log_bucket` is set."
  default     = "log/"
}

variable "worklytics_host" {
  type        = string
  description = "Hostname of the Worklytics instance (no scheme). Default app.worklytics.co; override for custom domains."
  default     = "app.worklytics.co"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$", var.worklytics_host))
    error_message = "`worklytics_host` must be a hostname without scheme or path (e.g. app.worklytics.co)."
  }
}
