resource "aws_s3_bucket" "bucket" {
  bucket_prefix       = "tf-state-userxx"
  # IMPORTANT: This must be here for Native Locking to work when remote state is enabled later - it cannot be added after creation
  object_lock_enabled = true
  tags = {
    Name        = "userxx Terraform State Bucket"
    Environment = "Prod"
  }
}

# Make the default explicit (ACLs disabled)
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Block all public access (good hygiene)
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
