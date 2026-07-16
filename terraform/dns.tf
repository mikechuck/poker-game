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

resource "aws_route53_record" "game_server" {
    zone_id = data.aws_route53_zone.main.zone_id
    name    = "server.mikechucktingle.net"
    type    = "A"

    alias {
        name                   = aws_lb.poker_alb.dns_name
        zone_id                = aws_lb.poker_alb.zone_id
        evaluate_target_health = true
    }
}

resource "aws_route53_record" "api_gateway" {
    zone_id = data.aws_route53_zone.main.zone_id
    name    = "api.mikechucktingle.net"
    type    = "A"

    alias {
        name                   = aws_apigatewayv2_domain_name.poker_api_domain.domain_name_configuration[0].target_domain_name
        zone_id                = aws_apigatewayv2_domain_name.poker_api_domain.domain_name_configuration[0].hosted_zone_id
        evaluate_target_health = true
    }
}

resource "aws_route53_record" "cognito_login_alias" {
    zone_id = data.aws_route53_zone.main.zone_id
    name    = "auth.mikechucktingle.net"
    type    = "A"

    alias {
        name                   = aws_cognito_user_pool_domain.poker_domain.cloudfront_distribution
        zone_id                = "Z2FDTNDATAQYW2" 
        evaluate_target_health = false
    }
}

# --- Start ALB configuration ---

# The Application Load Balancer configured for the default VPC subnets
resource "aws_lb" "poker_alb" {
    name               = "poker-game-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb_sg.id]
    subnets            = data.aws_subnets.default_public.ids

    tags = { Name = "PokerGameALB" }
}

# HTTP Target Group listening on the local Nginx proxy port (8000)
resource "aws_lb_target_group" "poker_ec2_8000" {
    name        = "poker-ec2-target-8000"
    port        = 8000
    protocol    = "HTTP"
    vpc_id      = data.aws_vpc.default.id
    target_type = "instance"

    health_check {
        path                = "/health"
        protocol            = "HTTP"
        port                = "8000"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        matcher             = "200-499"
    }
}

# Link the existing EC2 instance into the ALB Target Group
resource "aws_lb_target_group_attachment" "poker_attachment" {
    target_group_arn = aws_lb_target_group.poker_ec2_8000.arn
    target_id        = aws_instance.poker_server.id
    port             = 8000
}

# Create ALB Security Group to handle public web requests
resource "aws_security_group" "alb_sg" {
    name        = "poker-alb-sg"
    description = "Public edge entry point for secure HTTPS/WSS traffic"
    vpc_id      = data.aws_vpc.default.id

    ingress {
        from_port   = 443
        to_port     = 443
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

# ALB Listener on Port 443: Terminates wss:// handshakes using the data cert
resource "aws_lb_listener" "https_secure" {
    load_balancer_arn = aws_lb.poker_alb.arn
    port              = "443"
    protocol          = "HTTPS"
    ssl_policy        = "ELBSecurityPolicy-2016-08"
    certificate_arn   = data.aws_acm_certificate.poker_cert.arn

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.poker_ec2_8000.arn
    }
}


# --- End ALB configuration