output "bucket_name" {
  description = "The name of the S3 bucket to use for remote state"
  value       = module.s3_bucket.bucket_name
}

output "load_balancer_dns" {
  value = module.load_balancer.alb_dns_name
}