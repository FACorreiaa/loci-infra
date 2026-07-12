# Remote state on Hetzner Object Storage (S3-compatible).
#
# One-time setup before `terraform init`:
#   1. Create a bucket in the Hetzner Cloud console (Object Storage), e.g.
#      "loci-tfstate", in the same location you deploy to (fsn1/nbg1/hel1).
#   2. Create S3 credentials (access key + secret) for that project.
#   3. Export them so the backend can authenticate:
#        export AWS_ACCESS_KEY_ID=<hetzner-s3-access-key>
#        export AWS_SECRET_ACCESS_KEY=<hetzner-s3-secret-key>
#   4. Set the bucket/endpoint below to match your location, then:
#        terraform init
#
# Endpoint format: https://<location>.your-objectstorage.com  (e.g. fsn1)
terraform {
  backend "s3" {
    bucket = "loci-tfstate"
    key    = "loci/terraform.tfstate"
    region = "fsn1"

    endpoints = {
      s3 = "https://fsn1.your-objectstorage.com"
    }

    # Hetzner's S3 API is not AWS, so skip the AWS-specific preflight calls.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    use_path_style              = true
  }
}
