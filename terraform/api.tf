# --- Start API Gateway Config ---
resource "aws_apigatewayv2_api" "poker_api" {
    name          = "PokerAPI"
    protocol_type = "HTTP"

    cors_configuration {
        allow_credentials = true
        allow_headers     = ["authorization", "content-type"]
        allow_methods     = ["GET", "POST", "OPTIONS"]
        allow_origins     = ["https://poker.mikechucktingle.net", "http://localhost:5173"]
        max_age           = 0
    }
}

resource "aws_apigatewayv2_authorizer" "cognito_auth" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    authorizer_type  = "JWT"
    identity_sources = ["$request.header.Authorization"]
    name             = "CognitoJwtAuthorizer"

    jwt_configuration {
        audience = [aws_cognito_user_pool_client.poker_client.id]
        issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${aws_cognito_user_pool.poker_pool.id}"
    }
}

resource "aws_apigatewayv2_stage" "dev" {
    api_id      = aws_apigatewayv2_api.poker_api.id
    name        = "dev"
    auto_deploy = true
}

# Note: these are empty routes. When adding an integration, remove it from 
# this list and define it independently 
resource "aws_apigatewayv2_route" "routes" {
    for_each = toset(["POST /account/picture", "GET /debts"])
    
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = each.key
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

resource "aws_apigatewayv2_domain_name" "poker_api_domain" {
    domain_name = "api.mikechucktingle.net"

    domain_name_configuration {
        certificate_arn = data.aws_acm_certificate.poker_cert.arn
        endpoint_type   = "REGIONAL"
        security_policy = "TLS_1_2"
    }
}

resource "aws_apigatewayv2_api_mapping" "poker_mapping" {
    api_id      = aws_apigatewayv2_api.poker_api.id
    domain_name = aws_apigatewayv2_domain_name.poker_api_domain.id
    stage       = aws_apigatewayv2_stage.dev.id
}
# --- End API Gateway Config ---

# --- Start GetAccount API Gateway Integration ---

# Create the Integration
resource "aws_apigatewayv2_integration" "get_account_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.get_account.invoke_arn
    payload_format_version = "2.0"
}

# Update the existing Route to point to this integration
resource "aws_apigatewayv2_route" "get_account_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "GET /account"

    target             = "integrations/${aws_apigatewayv2_integration.get_account_int.id}"
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

# Grant Permission for API Gateway to invoke the Lambda
resource "aws_lambda_permission" "api_gw_get_account" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.get_account.function_name
    principal     = "apigateway.amazonaws.com"

    # Standard security: restrict access to your specific API
    source_arn = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*/account"
}

# --- End GetAccount API Gateway Integration ---

# --- Start CreateGame API Gateway Integration ---

resource "aws_apigatewayv2_integration" "create_game_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.create_game.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_game_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "PUT /game"

    target             = "integrations/${aws_apigatewayv2_integration.create_game_int.id}"
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

resource "aws_lambda_permission" "api_gw_create_game" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.create_game.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*/game"
}
# --- End CreateGame API Gateway Integration ---

resource "aws_iam_role" "lambda_integration_role" {
    name = "poker-get-account-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
            Service = "lambda.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_policy" "dynamo_poker_access" {
    name        = "poker-dynamo-access-policy"
    description = "Allows poker lambdas to read/write to Accounts and Debts tables"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = [
                    "dynamodb:PutItem",
                    "dynamodb:GetItem",
                    "dynamodb:UpdateItem",
                    "dynamodb:Query",
                    "dynamodb:Scan"
                ]
                Effect   = "Allow"
                Resource = [
                    aws_dynamodb_table.accounts_table.arn,
                    aws_dynamodb_table.debts_table.arn
                ]
            }
        ]
    })
}

# Standard CloudWatch logging permissions
resource "aws_iam_role_policy_attachment" "lambda_integration_logs" {
    role       = aws_iam_role.lambda_integration_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach the DynamoDB access policy
resource "aws_iam_role_policy_attachment" "lambda_integration_dynamo" {
    role       = aws_iam_role.lambda_integration_role.name
    policy_arn = aws_iam_policy.dynamo_poker_access.arn
}

# --- Start GetAccount Lambda Function ---

data "archive_file" "get_account_zip" {
    type        = "zip"
    source_dir  = "${path.module}/../src/functions/account/get_account"
    output_path = "${path.module}/get_account.zip"
}

resource "aws_lambda_function" "get_account" {
    function_name = "GetAccount"
    filename      = data.archive_file.get_account_zip.output_path
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 3
    memory_size   = 128

    source_code_hash = data.archive_file.get_account_zip.output_base64sha256

    environment {
        variables = {
            ACCOUNTS_TABLE = aws_dynamodb_table.accounts_table.name
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "get_account_logs" {
    name              = "/aws/lambda/GetAccount"
    retention_in_days = 7
}

# --- End GetAccount Lambda Function ---

# --- Start CreateGame Lambda Function ---

data "archive_file" "create_game_zip" {
    type        = "zip"
    source_dir  = "${path.module}/../src/functions/game/create_game"
    output_path = "${path.module}/create_game.zip"
}

resource "aws_lambda_function" "create_game" {
    function_name = "CreateGame"
    filename      = data.archive_file.create_game_zip.output_path
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 3
    memory_size   = 128

    source_code_hash = data.archive_file.create_game_zip.output_base64sha256

    environment {
        variables = {
            GAMES_TABLE = aws_dynamodb_table.games_table.name
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "create_game_logs" {
    name              = "/aws/lambda/CreateGame"
    retention_in_days = 7
}

# --- End CreateGame Lambda Function ---