output "api_url" {
  description = "URL completo del API"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/upload"
}

output "bucket_name" {
  description = "Nombre del bucket S3"
  value       = aws_s3_bucket.images.bucket
}

output "upload_lambda_name" {
  description = "Nombre de la función upload"
  value       = aws_lambda_function.upload.function_name
}

output "crop_lambda_name" {
  description = "Nombre de la función crop"
  value       = aws_lambda_function.crop.function_name
}