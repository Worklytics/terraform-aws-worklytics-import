variable "aws_account_id" {
  type        = string
  description = "AWS account in which to provision. Required to be explicitly specified, to reduce chance of inadvertently provisioning in the wrong account."
}

variable "aws_region" {
  type        = string
  description = "AWS region for the example provider. Required by AWS provider 3.x."
  default     = "us-west-2"
}

variable "aws_role_name" {
  type        = string
  description = "The name of the role to assume within the AWS account. `null` if already auth'd as the desired role/user."
  default     = null
}

variable "resource_name_prefix" {
  type        = string
  description = "Prefix to give to names of infra created by this module, where applicable."
  default     = "worklytics-import-"
}

variable "worklytics_tenant_id" {
  type        = string
  description = "Numeric ID of your Worklytics tenant's service account (obtain from Worklytics App)."
}

variable "worklytics_tenant_sa_email" {
  type        = string
  description = "Optional email of your Worklytics tenant's GCP service account."
  default     = null
}

variable "s3_bucket_name" {
  type        = string
  description = "Existing S3 bucket to reuse. If null and s3_bucket_names is empty, the module creates one."
  default     = null
}

variable "s3_bucket_names" {
  type        = list(string)
  description = "Optional additional existing S3 buckets to grant Worklytics access to."
  default     = []
}

variable "enable_aws_s3_bucket_public_access_block" {
  type        = bool
  description = "Whether to place a restrictive public-access block on a bucket created by this module."
  default     = true
}

variable "enable_aws_s3_bucket_versioning" {
  type        = bool
  description = "Whether to enable versioning on a bucket created by this module."
  default     = false
}

variable "aws_s3_access_log_bucket" {
  type        = string
  description = "Optional destination bucket for server access logs of a created import bucket."
  default     = null
}

variable "aws_s3_access_log_prefix" {
  type        = string
  description = "Prefix for S3 server access log keys when logging is enabled."
  default     = "log/"
}

variable "todos_as_local_files" {
  type        = bool
  description = "Whether to render TODOs as flat files."
  default     = true
}
