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
    ttl     = 300
    records = [aws_eip.poker_server_eip.public_ip]
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