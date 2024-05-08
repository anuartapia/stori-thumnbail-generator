variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "thumbnail_lambda_memory" {
  type    = number
  default = 256
}
variable "max_thumbnail_width" {
  description = "Maximum width in pixels for thumbnails"
  type        = number
  default     = 300
}
variable "max_thumbnail_height" {
  description = "Maximum height in pixels for thumbnails"
  type        = number
  default     = 300
}