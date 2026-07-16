data "aws_cloudfront_function" "redirect_to_index" {
    name  = "RedirectToIndex"
    stage = "LIVE"
}

resource "aws_cloudfront_origin_request_policy" "godot_requests" {
    name    = "godot-web-requests"
    cookies_config { cookie_behavior = "none" }
    headers_config {
        header_behavior = "whitelist"
        headers { items = ["Origin"] }
    }
    query_strings_config { query_string_behavior = "none" }
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
            override = true
        }
        referrer_policy {
            referrer_policy = "no-referrer-when-downgrade"
            override = true
        }
        content_security_policy {
            content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' blob:; media-src 'self' blob:; font-src 'self' data:; worker-src 'self' blob:; connect-src 'self' *.mikechucktingle.net mikechucktingle.net wss://server.mikechucktingle.net; object-src 'none'; frame-ancestors 'self';"
            override                = true
        }
    }
    custom_headers_config {
        items {
            header = "Cross-Origin-Opener-Policy"
            value = "same-origin"
            override = true
        }
        items {
            header = "Cross-Origin-Embedder-Policy"
            value = "require-corp"
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
    default_root_object = "index.html"
    price_class         = "PriceClass_All"
    aliases             = ["poker.mikechucktingle.net"]

    origin {
        domain_name = aws_lb.poker_alb.dns_name
        origin_id   = "ec2-poker-server"
        custom_origin_config {
            http_port              = 80
            https_port             = 443
            origin_protocol_policy = "https-only"
            origin_ssl_protocols   = ["TLSv1.2"]
        }
        custom_header {
            name = "X-Origin-Verify"
            value = random_password.tcp_request_token.result
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
            lambda_arn   = aws_lambda_function.server_edge_auth_lambda.qualified_arn 
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

        function_association {
            event_type = "viewer-request"
            function_arn = data.aws_cloudfront_function.redirect_to_index.arn
        }
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

# --- Start S3 Hosting Config ---
resource "aws_s3_bucket" "poker_bucket" {
    bucket        = "chuckycodes-poker-game"
    force_destroy = true 
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