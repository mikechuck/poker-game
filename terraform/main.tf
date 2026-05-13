# Requirements: ensure to run "aws configure" so terraform has correct permissions

provider "aws" {
    alias  = "us_east_1"
    region = "us-east-1"
}

data "aws_acm_certificate" "poker_cert" {
    domain   = "mikechucktingle.net"
    statuses = ["ISSUED"]
}