# Private bucket that hands the admin token over to the runner module.
#
# The server and runner modules are separate Terraform roots that may run on
# different machines (e.g. two Semaphore tasks), so a local file in /tmp is not
# a reliable channel. The token is uploaded here right after it is minted and
# the runner module reads it with an aws_s3_object data source.
#
# Written for Cloudflare R2 through its S3 API (see provider.tf): R2 buckets are
# private and encrypted at rest by default and R2 does not implement
# PutPublicAccessBlock, PutBucketTagging or the SSE headers, so none of the
# usual AWS hardening resources are declared here.
resource "aws_s3_bucket" "stand" {
  bucket        = local.s3_bucket
  force_destroy = true # the bucket only holds the token; destroy must not get stuck on it
}

resource "aws_s3_object" "admin_token" {
  bucket       = aws_s3_bucket.stand.id
  key          = local.admin_token_s3_key
  content      = data.local_sensitive_file.admin_token.content
  content_type = "text/plain" # lets the runner's aws_s3_object data source expose `body`
}
