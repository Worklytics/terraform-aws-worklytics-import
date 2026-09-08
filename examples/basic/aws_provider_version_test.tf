# Default provider pin for this example. GitHub Actions overwrites this file
# during the AWS 3.x/6.x compatibility matrix (same filename) so there is only
# one required_providers block in the example module.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
}
