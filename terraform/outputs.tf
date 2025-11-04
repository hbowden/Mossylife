output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (use this URL to access the site)"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "cloudfront_url" {
  description = "Full CloudFront URL"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name for website content"
  value       = aws_s3_bucket.website.id
}

output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "api_gateway_track_endpoint" {
  description = "Full analytics tracking endpoint"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/track"
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for analytics"
  value       = aws_dynamodb_table.analytics.name
}

output "lambda_function_name" {
  description = "Lambda function name for analytics"
  value       = aws_lambda_function.analytics.function_name
}

output "route53_nameservers" {
  description = "Route 53 nameservers (add these to your domain registrar)"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : []
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = var.domain_name != "" ? aws_acm_certificate.cert[0].arn : null
}

output "domain_url" {
  description = "Your custom domain URL (if configured)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "Not configured - using CloudFront URL"
}
