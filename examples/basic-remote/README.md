# Registry example (customer-facing)

Copy this pattern into your own root module. `source` / `version` are the Terraform Registry
coordinates. Configure an `aws` provider and a **remote** backend in that root module; this file
omits them so it stays a short snippet.

The optional `local_file` writes remaining Worklytics console steps. Omit it if you only need
the `todo_markdown` output. Requires the `hashicorp/local` provider in your root module.

This example is **import only** (customer S3 → Worklytics). For Worklytics → your AWS account,
use [`terraform-aws-worklytics-export`](https://github.com/Worklytics/terraform-aws-worklytics-export).

See the [root README](../../README.md) for usage tips (existing buckets, role composition,
versioning, logging). The Terraform Registry lists inputs and outputs from the `.tf` files.
