# Registry example (customer-facing)

Copy this pattern into your own root module. `source` / `version` are the Terraform Registry
coordinates. Configure an `aws` provider and a **remote** backend in that root module; this file
omits them so it stays a short snippet.

This example is **import only** (customer S3 → Worklytics). For Worklytics → your AWS account,
use [`terraform-aws-worklytics-export`](https://github.com/Worklytics/terraform-aws-worklytics-export).

See the [root README](../../README.md) for the full variable set.
