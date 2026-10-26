# Admin API token of the stand, uploaded to S3 by the server module
# (ha_stand/do/server/s3.tf). It authenticates the semaphoreui provider and the
# registration-token calls made from the runner droplets.
#
# Not read with skip_server: `terraform destroy` still reads data sources, and a
# missing bucket/object would abort the destroy before any droplet is removed.
data "aws_s3_object" "admin_token" {
  count  = var.skip_server ? 0 : 1
  bucket = local.s3_bucket
  key    = local.admin_token_s3_key
}
