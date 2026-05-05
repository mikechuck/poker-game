# Requirements: ensure to run "aws configure" so terraform has correct permissions
# Resources to add:
# - S3 front end 
# - any IAM users, roles, policies, etc

# --- Provider Configuration ---
provider "aws" {
    region = "us-east-1"
}

# --- Certificate arn for anything using the custom domain ---
data "aws_acm_certificate" "poker_cert" {
  domain   = "mikechucktingle.net"
  statuses = ["ISSUED"]
}

# --- Data Source for UserData ---
# We use a templatefile to keep the Bash script clean
locals {
    user_data = templatefile("${path.module}/startup.sh", {
        bucketName = "chuckycodes-games"
        s3Prefix = "poker-game/server/linux"
    })
}

# --- Security Group ---
resource "aws_security_group" "poker_sg" {
    name = "poker-game-sg"
    description = "Nginx front door"

    ingress {
        from_port = 8000
        to_port = 8000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# --- EC2 Instance ---
resource "aws_instance" "poker_server" {
    ami = "ami-0341d95f75f311023"
    instance_type = "t3.micro"
    iam_instance_profile = "game-server-ec2-role"
    vpc_security_group_ids = [aws_security_group.poker_sg.id]
    user_data = local.user_data
    tags = {
        Name = "PokerGameServer"
    }
}

# --- S3 Bucket for Frontend Hosting ---
resource "aws_s3_bucket" "poker_bucket" {
    bucket = "chuckycodes-poker-game"

    # The files are uploaded during deployment, we can delete the bucket with files in it
    force_destroy = true 

    tags = {
        Name = "Poker Game Frontend"
    }
}

# --- Block Public Access (Standard Security Best Practice) ---
resource "aws_s3_bucket_public_access_block" "poker_bucket_block" {
    bucket = aws_s3_bucket.poker_bucket.id

    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# --- Set CORS policy on the S3 bucket
resource "aws_s3_bucket_cors_configuration" "poker_cors" {
  bucket = aws_s3_bucket.poker_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = [
      "https://ddfh2856132nt.cloudfront.net",
      "https://poker.mikechucktingle.net"
    ]
    expose_headers  = []
    max_age_seconds = 3000
  }
}

# --- Custom Origin Request Policy: godot-web-requests ---
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

        content_type_options {
            override = true
        }

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
        # REQUIRED FOR GODOT WEB EXPORTS
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

# --- CloudFront Origin Access Control (OAC) ---
resource "aws_cloudfront_origin_access_control" "poker_oac" {
    name                              = "godot-origin-access-control"
    description                       = ""
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
}

# --- Cloudfront distribution ---
resource "aws_cloudfront_distribution" "poker_cdn" {
    enabled             = true
    is_ipv6_enabled     = true
    comment             = "Poker Game, both front end requests to game server"
    default_root_object = "index.html"
    price_class         = "PriceClass_All"
    aliases             = ["poker.mikechucktingle.net"]

    # --- Origin: EC2 Game Server ---
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

    # --- Origin: S3 Web Client ---
    origin {
        domain_name = aws_s3_bucket.poker_bucket.bucket_regional_domain_name
        origin_id   = aws_s3_bucket.poker_bucket.bucket_regional_domain_name
        origin_access_control_id = aws_cloudfront_origin_access_control.poker_oac.id
    }

    # --- BEHAVIOR: /game/* (EC2) ---
    ordered_cache_behavior {
        path_pattern     = "/game/*"
        target_origin_id = "ec2-poker-server"

        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        compress         = true

        viewer_protocol_policy = "https-only"

        cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
        origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer
    }

    # --- DEFAULT BEHAVIOR: (*) (S3 Frontend) ---
    default_cache_behavior {
        target_origin_id = "chuckycodes-poker-game.s3.us-east-1.amazonaws.com"

        # From image_65eda0: All methods allowed
        allowed_methods  = ["GET", "HEAD", "OPTIONS"]
        cached_methods   = ["GET", "HEAD"]
        compress         = true
        viewer_protocol_policy = "redirect-to-https"

        # From image_65ed84: Managed and Custom Policies
        cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
        origin_request_policy_id   = aws_cloudfront_origin_request_policy.godot_requests.id
        response_headers_policy_id = aws_cloudfront_response_headers_policy.godot_response.id

        function_association {
            event_type   = "viewer-request"
            function_arn = "arn:aws:cloudfront::072351085675:function/RedirectToIndex"
        }
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        acm_certificate_arn      = data.aws_acm_certificate.poker_cert.arn
        ssl_support_method       = "sni-only"
        minimum_protocol_version = "TLSv1.2_2021"
    }

    tags = {
        Name = "poker-game"
    }
}

# --- Update S3 policies ---
resource "aws_s3_bucket_policy" "poker_bucket_policy" {
  bucket = aws_s3_bucket.poker_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id: "PolicyForCloudFrontPrivateContent",
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::chuckycodes-poker-game/*"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.poker_cdn.arn
          }
        }
      }
    ]
  })
}