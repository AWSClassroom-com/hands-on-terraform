output "bucket_name" {
  description = "The name of the S3 bucket to use for remote state"
  value       = aws_s3_bucket.bucket.id
}
output "load_balancer_dns" {
  value = aws_lb.web_alb.dns_name
}