# Requirements: ensure to run "aws configure" so terraform has correct permissions

# --- Start Provider Configuration ---
provider "aws" {
    region = "us-east-1"
}

provider "aws" {
    alias  = "us_east_1"
    region = "us-east-1"
}
# --- End Provider Configuration ---

# --- Start Global Data Sources ---
data "aws_acm_certificate" "poker_cert" {
    domain   = "mikechucktingle.net"
    statuses = ["ISSUED"]
}
# --- End Global Data Sources ---

# --- Start Route53 Config ---
data "aws_route53_zone" "main" {
    zone_id = "Z0053251XXT1FWAUMZOS" 
}

resource "aws_route53_record" "poker_frontend" {
    zone_id = data.aws_route53_zone.main.zone_id
    name    = "poker.mikechucktingle.net"
    type    = "A"

    alias {
        name                   = aws_cloudfront_distribution.poker_cdn.domain_name
        zone_id                = aws_cloudfront_distribution.poker_cdn.hosted_zone_id
        evaluate_target_health = false
    }
}

resource "aws_route53_record" "cognito_login" {
    zone_id = data.aws_route53_zone.main.zone_id
    name    = "login.mikechucktingle.net"
    type    = "CNAME"
    ttl     = 300
    records = [aws_cognito_user_pool_domain.poker_domain.cloudfront_distribution_arn]
}

resource "aws_route53_record" "game_server" {
    zone_id = data.aws_route53_zone.main.zone_id
    name    = "server.mikechucktingle.net"
    type    = "A"

    alias {
        name                   = aws_instance.poker_server.public_dns
        zone_id                = "Z35SXDOTRQ7X7K" 
        evaluate_target_health = true
    }
}

resource "aws_route53_record" "api_gateway" {
    zone_id = data.aws_route53_zone.main.zone_id
    name    = "api.mikechucktingle.net"
    type    = "A"

    alias {
        name                   = aws_api_gateway_domain_name.main.cloudfront_domain_name
        zone_id                = aws_api_gateway_domain_name.main.cloudfront_zone_id
        evaluate_target_health = true
    }
}

resource "aws_route53_record" "cert_validation" {
    for_each = {
        for dvo in data.aws_acm_certificate.poker_cert.domain_validation_options : dvo.domain_name => {
            name   = dvo.resource_record_name
            record = dvo.resource_record_value
            type   = dvo.resource_record_type
        }
    }

    allow_overwrite = true
    name            = each.value.name
    records         = [each.value.record]
    ttl             = 60
    type            = each.value.type
    zone_id         = data.aws_route53_zone.main.zone_id
}
# --- End Route53 Config ---

# --- Start Cognito Config ---
resource "aws_cognito_user_pool" "poker_pool" {
    name = "poker-user-pool"

    username_attributes = ["email"]
    auto_verified_attributes = ["email"]

    password_policy {
        minimum_length                   = 8
        require_lowercase                = true
        require_numbers                  = true
        require_symbols                  = true
        require_uppercase                = true
        temporary_password_validity_days = 7
    }

    schema {
        attribute_data_type = "String"
        name                = "email"
        required            = true
        mutable             = true
    }

    admin_create_user_config {
        allow_admin_create_user_only = false
    }

    mfa_configuration = "OFF"

    email_configuration {
        email_sending_account = "COGNITO_DEFAULT"
    }

    tags = {
        Name = "PokerGameUserPool"
    }
}

resource "aws_cognito_user_pool_client" "poker_client" {
    name         = "Poker"
    user_pool_id = aws_cognito_user_pool.poker_pool.id

    explicit_auth_flows = [
        "ALLOW_REFRESH_TOKEN_AUTH",
        "ALLOW_USER_SRP_AUTH"
    ]

    allowed_oauth_flows_user_pool_client = true
    allowed_oauth_flows                  = ["code"] 
    allowed_oauth_scopes                 = ["email", "openid", "phone"]

    callback_urls = [
        "http://localhost:5173/",
        "https://poker.mikechucktingle.net/"
    ]

    id_token_validity      = 60
    access_token_validity  = 60
    refresh_token_validity = 5

    token_validity_units {
        id_token      = "minutes"
        access_token  = "minutes"
        refresh_token = "days"
    }

    generate_secret = false
}

resource "aws_cognito_user_pool_domain" "poker_domain" {
    domain          = "login.mikechucktingle.net"
    certificate_arn = data.aws_acm_certificate.poker_cert.arn 
    user_pool_id    = aws_cognito_user_pool.poker_pool.id
}
# --- End Cognito Config ---

# --- Start Networking & Security Groups ---
resource "aws_security_group" "poker_sg" {
    name        = "poker-game-sg"
    description = "Nginx front door"

    ingress {
        from_port   = 8000
        to_port     = 8000
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
# --- End Networking & Security Groups ---

# --- Start IAM Roles & Policies ---
# EC2 Role
resource "aws_iam_role" "ec2_logs_role" {
    name = "poker-game-ec2-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "ec2.amazonaws.com" }
        }]
    })
}

resource "aws_iam_instance_profile" "ec2_profile" {
    name = "poker-game-ec2-profile"
    role = aws_iam_role.ec2_logs_role.name
}

resource "aws_iam_role_policy_attachment" "cw_agent_policy" {
    role       = aws_iam_role.ec2_logs_role.name
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Lambda Edge Role
resource "aws_iam_role" "lambda_edge_role" {
    name = "poker-auth-edge-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
            }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "edge_logs" {
  role       = aws_iam_role.lambda_edge_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
# --- End IAM Roles & Policies ---

# --- Start CloudWatch & Logging ---
resource "aws_cloudwatch_log_group" "node_app_logs" {
    name              = "/apps/poker-game"
    retention_in_days = 7
}

resource "aws_ssm_parameter" "cw_agent_config" {
    name  = "amazon-cloudwatch-agent-config"
    type  = "String"
    value = jsonencode({
        metrics = {
            metrics_collected = {
                mem = {
                    measurement = ["mem_used_percent"]
                    metrics_collection_interval = 60
                }
            }
        }
        logs = {
            logs_collected = {
                files = {
                    collect_list = [
                        {
                            file_path       = "/home/ec2-user/logs/*.log"
                            log_group_name  = "/apps/poker-game"
                            log_stream_name = "{instance_id}"
                        }
                    ]
                }
            }
        }
    })
}
# --- End CloudWatch & Logging ---

# --- Start Lambda Edge Config ---
data "template_file" "lambda_source" {
    template = file("${path.module}/auth_edge.js.tpl")
    vars = {
        region         = "us-east-1"
        user_pool_id   = aws_cognito_user_pool.poker_pool.id
        app_client_id  = aws_cognito_user_pool_client.poker_client.id
    }
}

data "archive_file" "lambda_zip" {
    type        = "zip"
    output_path = "${path.module}/auth_edge.zip"
    source {
        content  = data.template_file.lambda_source.rendered
        filename = "index.js"
    }
}

resource "aws_lambda_function" "auth_edge" {
    provider      = aws.us_east_1 
    function_name = "poker-auth-at-edge"
    role          = aws_iam_role.lambda_edge_role.arn
    handler       = "index.handler"
    runtime       = "nodejs20.x"
    publish       = true

    filename         = data.archive_file.lambda_zip.output_path
    source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}
# --- End Lambda Edge Config ---

# --- Start EC2 Instance Config ---
locals {
    user_data = templatefile("${path.module}/startup.sh", {
        bucketName        = "chuckycodes-games"
        s3Prefix          = "poker-game/server/linux"
        cwAgentConfigName = aws_ssm_parameter.cw_agent_config.name
    })
}

resource "aws_instance" "poker_server" {
    ami                    = "ami-0341d95f75f311023"
    instance_type          = "t3.micro"
    iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
    vpc_security_group_ids = [aws_security_group.poker_sg.id]
    user_data              = local.user_data
    tags = {
        Name = "PokerGameServer"
    }
}
# --- End EC2 Instance Config ---

# --- Start S3 Hosting Config ---
resource "aws_s3_bucket" "poker_bucket" {
    bucket        = "chuckycodes-poker-game"
    force_destroy = true 

    tags = {
        Name = "Poker Game Frontend"
    }
}

resource "aws_s3_bucket_public_access_block" "poker_bucket_block" {
    bucket = aws_s3_bucket.poker_bucket.id

    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "poker_bucket_policy" {
    bucket = aws_s3_bucket.poker_bucket.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action   = "s3:GetObject"
            Effect   = "Allow"
            Resource = "${aws_s3_bucket.poker_bucket.arn}/*"
            Principal = { Service = "cloudfront.amazonaws.com" }
            Condition = {
                StringEquals = {
                    "AWS:SourceArn" = aws_cloudfront_distribution.poker_cdn.arn
                }
            }
        }]
    })
}

resource "aws_s3_bucket_cors_configuration" "poker_cors" {
    bucket = aws_s3_bucket.poker_bucket.id

    cors_rule {
        allowed_headers = ["*"]
        allowed_methods = ["GET"]
        allowed_origins = [
            "https://${aws_cloudfront_distribution.poker_cdn.domain_name}",
            "https://poker.mikechucktingle.net"
        ]
        expose_headers  = []
        max_age_seconds = 3000
    }
}
# --- End S3 Hosting Config ---

# --- Start CloudFront Config ---
resource "aws_cloudfront_origin_request_policy" "godot_requests" {
    name    = "godot-web-requests"
    comment = "Origin request policy for Godot web client headers"

    cookies_config {
        cookie_behavior = "none"
    }

    headers_config {
        header_behavior = "whitelist"
        headers {
            items = ["Origin"]
        }
    }

    query_strings_config {
        query_string_behavior = "none"
    }
}

resource "aws_cloudfront_response_headers_policy" "godot_response" {
    name = "godot-response-headers"

    security_headers_config {
        strict_transport_security {
            access_control_max_age_sec = 31536000
            include_subdomains         = true
            preload                    = true
            override                   = true
        }
        content_type_options { override = true }
        frame_options {
            frame_option = "SAMEORIGIN"
            override     = true
        }
        referrer_policy {
            referrer_policy = "no-referrer-when-downgrade"
            override        = true
        }
        content_security_policy {
            content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' blob:; media-src 'self' blob:; font-src 'self' data:; worker-src 'self' blob:; connect-src 'self' *.mikechucktingle.net mikechucktingle.net; object-src 'none'; frame-ancestors 'self';"
            override                = true
        }
    }

    custom_headers_config {
        items {
            header   = "Cross-Origin-Opener-Policy"
            value    = "same-origin"
            override = true
        }
        items {
            header   = "Cross-Origin-Embedder-Policy"
            value    = "require-corp"
            override = true
        }
    }
}

resource "aws_cloudfront_origin_access_control" "poker_oac" {
    name                              = "godot-origin-access-control"
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "poker_cdn" {
    enabled             = true
    is_ipv6_enabled     = true
    comment             = "Poker Game Distribution"
    default_root_object = "index.html"
    price_class         = "PriceClass_All"
    aliases             = ["poker.mikechucktingle.net"]

    origin {
        domain_name = aws_instance.poker_server.public_dns
        origin_id   = "ec2-poker-server"
        custom_origin_config {
            http_port              = 8000
            https_port             = 443
            origin_protocol_policy = "http-only"
            origin_ssl_protocols   = ["TLSv1.2"]
        }
    }

    origin {
        domain_name = aws_s3_bucket.poker_bucket.bucket_regional_domain_name
        origin_id   = aws_s3_bucket.poker_bucket.id
        origin_access_control_id = aws_cloudfront_origin_access_control.poker_oac.id
    }

    ordered_cache_behavior {
        path_pattern     = "/game/*"
        target_origin_id = "ec2-poker-server"
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        compress         = true
        viewer_protocol_policy = "https-only"
        cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" 
        origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" 

        lambda_function_association {
            event_type   = "viewer-request"
            lambda_arn   = aws_lambda_function.auth_edge.qualified_arn 
            include_body = false
        }
    }

    default_cache_behavior {
        target_origin_id = aws_s3_bucket.poker_bucket.id
        allowed_methods  = ["GET", "HEAD", "OPTIONS"]
        cached_methods   = ["GET", "HEAD"]
        compress         = true
        viewer_protocol_policy = "redirect-to-https"
        cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" 
        origin_request_policy_id   = aws_cloudfront_origin_request_policy.godot_requests.id
        response_headers_policy_id = aws_cloudfront_response_headers_policy.godot_response.id
    }

    restrictions {
        geo_restriction { restriction_type = "none" }
    }

    viewer_certificate {
        acm_certificate_arn      = data.aws_acm_certificate.poker_cert.arn
        ssl_support_method       = "sni-only"
        minimum_protocol_version = "TLSv1.2_2021"
    }
}
# --- End CloudFront Config ---