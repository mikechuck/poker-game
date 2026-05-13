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

    supported_identity_providers = ["COGNITO"]

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
    domain          = "auth.mikechucktingle.net"
    certificate_arn = data.aws_acm_certificate.poker_cert.arn 
    user_pool_id    = aws_cognito_user_pool.poker_pool.id
}

resource "aws_cognito_managed_login_branding" "poker_branding" {
    user_pool_id = aws_cognito_user_pool.poker_pool.id
    client_id    = aws_cognito_user_pool_client.poker_client.id
    
    # If you just want the clean, updated AWS look:
    use_cognito_provided_values = true
}