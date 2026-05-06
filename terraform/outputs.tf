output "api_url" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "bucket_name" {
  value = aws_s3_bucket.images.bucket
}