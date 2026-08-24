terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.31"
    }
  }

  # NOTE: The backend was configured in an earlier lab with:
  # terraform init -migrate-state -backend-config="bucket=<YOUR_CREATED_BUCKET_NAME>" -backend-config="region=<REGION>"
  #
  backend "s3" {
    key          = "aws/my-app/terraform.tfstate"
    use_lockfile = true # S3 native state locking (default is false)
  }
}

provider "aws" {
  region = var.region
}