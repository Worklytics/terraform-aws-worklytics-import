# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

### Changed
- Document that this module is import-only (customer premises → Worklytics). Outbound data
  (Worklytics → customer premises) uses [`terraform-aws-worklytics-export`](https://github.com/Worklytics/terraform-aws-worklytics-export).
- Connection TODOs deep-link to production `https://app.worklytics.co/analytics/connect/s3-import`
  (override host via `worklytics_host` for custom domains).

### Added
- Initial module to set up an Amazon S3 landing zone for importing data into Worklytics.
- Optional creation of an S3 bucket; existing names are reused when `s3_bucket_name` and/or
  `s3_bucket_names` are provided.
- IAM role allowing the Worklytics tenant GCP service account to assume via
  `sts:AssumeRoleWithWebIdentity` (Google → AWS), keyed by the tenant's 21-digit unique ID.
- IAM policy granting `s3:ListBucket` on each bucket and `s3:GetObject` / `s3:PutObject` /
  `s3:DeleteObject` on objects (ingest + checkpoints).
- Native `terraform test` unit tests (mocked AWS provider) and a GitHub Actions integration test
  that applies the module in AWS and round-trips an object as the federated GCP identity.
- Maintainer release helper (`tools/release.sh`) that tags `origin/main` only after required CI
  checks pass.
- Requires Terraform 1.1+ and AWS provider >= 3.0.
