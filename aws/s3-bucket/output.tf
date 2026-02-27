output "bucket_name" {
  description = "The name of the S3 bucket to use for remote state"
  value       = aws_s3_bucket.bucket.id
}
