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

# Generate a secure random string for the server-to-server connection
resource "random_password" "server_api_token" {
    length  = 32
    special = false
}

# Securely store this private token inside the SSM Parameter Store
resource "aws_ssm_parameter" "server_api_token" {
    name        = "/poker/server/api_token"
    type        = "SecureString"
    value       = random_password.server_api_token.result
    description = "Private token for EC2 to bypass public user authentication gates"
}

# Generate a secure random string for the nginx router to validate that requests are coming from the ALB
resource "random_password" "tcp_request_token" {
    length  = 32
    special = false
}

# Securely store this private token inside the SSM Parameter Store
resource "aws_ssm_parameter" "tcp_request_token" {
    name        = "/poker/server/tcp_token"
    type        = "SecureString"
    value       = random_password.tcp_request_token.result
    description = "Private token for EC2 nginx to validate tcp requests to ensure they are coming from ALB"
}
