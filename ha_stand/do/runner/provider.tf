provider "digitalocean" {
  token = var.do_token
}

provider "semaphoreui" {
  api_base_url    = local.api_base_url
  api_token       = local.api_token
  tls_skip_verify = false
}

# S3 client for the admin token hand-over. Points at Cloudflare R2 (or any other
# S3-compatible store) when s3_endpoint is set, at AWS S3 otherwise. The skip_*
# flags are what R2 needs: there is no AWS account to validate and "auto" is not
# an AWS region. R2 also rejects the SDK's default request checksums; the
# provider has no argument for that, so the SDK is told through the environment
# (AWS_REQUEST_CHECKSUM_CALCULATION / AWS_RESPONSE_CHECKSUM_VALIDATION =
# when_required, see ha_stand/.env.example).
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key != "" ? var.aws_access_key : null
  secret_key = var.aws_secret_key != "" ? var.aws_secret_key : null

  skip_credentials_validation = var.s3_endpoint != ""
  skip_region_validation      = var.s3_endpoint != ""
  skip_requesting_account_id  = var.s3_endpoint != ""
  skip_metadata_api_check     = var.s3_endpoint != ""
  s3_use_path_style           = var.s3_endpoint != ""

  endpoints {
    s3 = var.s3_endpoint != "" ? var.s3_endpoint : null
  }
}
