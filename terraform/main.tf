# Requirements: ensure to run "aws configure" so terraform has correct permissions

provider "aws" {
    alias  = "us_east_1"
    region = "us-east-1"
}

data "aws_acm_certificate" "poker_cert" {
    domain   = "mikechucktingle.net"
    statuses = ["ISSUED"]
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}