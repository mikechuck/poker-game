# --- Start API Gateway Config ---
resource "aws_apigatewayv2_api" "poker_api" {
    name          = "PokerAPI"
    protocol_type = "HTTP"

    cors_configuration {
        allow_credentials = true
        allow_headers     = ["authorization", "content-type"]
        allow_methods     = ["GET", "POST", "OPTIONS", "PUT", "DELETE"]
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

resource "aws_apigatewayv2_authorizer" "server_token_auth" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    authorizer_type  = "REQUEST"
    authorizer_uri   = aws_lambda_function.server_auth_lambda.invoke_arn
    identity_sources = ["$request.header.x-server-token"] # Expected private auth header
    name             = "ServerTokenAuthorizer"

    authorizer_payload_format_version = "2.0"
    enable_simple_responses          = true # Returns a clean true/false output
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
                    aws_dynamodb_table.debts_table.arn,
                    aws_dynamodb_table.games_table.arn,
                    "${aws_dynamodb_table.games_table.arn}/index/*"
                ]
            }
        ]
    })
}

resource "aws_iam_policy" "ssm_poker_server_access" {
    name        = "poker-ssm-server-access-policy"
    description = "Allows CreateGame lambda to execute shell scripts on the game server via SSM"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "ssm:SendCommand"
                ]
                # Lock it down strictly to your game server instance
                Resource = [
                    "arn:aws:ec2:*:*:instance/${aws_instance.poker_server.id}"
                ]
            },
            {
                Effect = "Allow"
                Action = [
                    "ssm:SendCommand"
                ]
                # Required document helper when sending terminal commands
                Resource = [
                    "arn:aws:ssm:*:*:document/AWS-RunShellScript"
                ]
            },
            {
                Effect = "Allow"
                Action = [
                    "ssm:GetCommandInvocation",
                    "ssm:ListCommandInvocations"
                ]
                # Checking statuses and reading outputs requires global resource context
                Resource = ["*"]
            }
        ]
    })
}

resource "aws_iam_role" "authorizer_lambda_role" {
    name = "poker-authorizer-execution-role"

    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
            Action    = "sts:AssumeRole"
            Effect    = "Allow"
            Principal = { Service = "lambda.amazonaws.com" }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "authorizer_basic_logs" {
  role       = aws_iam_role.authorizer_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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

# Attach the SSM access policy
resource "aws_iam_role_policy_attachment" "lambda_integration_ssm" {
    role       = aws_iam_role.lambda_integration_role.name
    policy_arn = aws_iam_policy.ssm_poker_server_access.arn
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

# --- Start GetGame API Gateway Integration ---

resource "aws_apigatewayv2_integration" "get_game_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.get_game.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_game_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "GET /game"

    target             = "integrations/${aws_apigatewayv2_integration.get_game_int.id}"
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

resource "aws_lambda_permission" "api_gw_get_game" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.get_game.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*/game"
}

# --- End CreateGame API Gateway Integration ---

# --- Start UpdateGame API Gateway Integration ---

resource "aws_apigatewayv2_integration" "update_game_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.update_game.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "update_game_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "POST /game/{gameId}"
    target    = "integrations/${aws_apigatewayv2_integration.update_game_int.id}"
    authorization_type = "CUSTOM"
    authorizer_id      = aws_apigatewayv2_authorizer.server_token_auth.id # Currently only the server can hit this endpoint
}

resource "aws_lambda_permission" "api_gw_update_game" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.update_game.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*/game/*"
}

# --- End UpdateGame API Gateway Integration ---

# --- Start Private Authorizer Lambda Function ---

data "archive_file" "server_auth_zip" {
    type        = "zip"
    source_dir  = "${path.module}/../src/functions/ServerAuthorizer"
    output_path = "${path.module}/exports/lambda/PrivateAuthorizer.zip"
}

resource "aws_lambda_function" "server_auth_lambda" {
    function_name = "ServerAuthorizer"
    filename      = data.archive_file.server_auth_zip.output_path
    role          = aws_iam_role.authorizer_lambda_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x"
    timeout       = 5
    memory_size   = 128

    source_code_hash = data.archive_file.server_auth_zip.output_base64sha256

    environment {
        variables = {
            SERVER_SECRET_TOKEN = random_password.server_api_token.result
        }
    }
}

# Didn't need to do this for the cognito authorizer because it's a built-in resource
resource "aws_lambda_permission" "api_gw_to_auth_lambda" {
    statement_id  = "AllowAuthorizerExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.server_auth_lambda.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*"
}

# --- End Private Authorizer Lambda Function

# --- Start GetAccount Lambda Function ---

data "archive_file" "get_account_zip" {
    type        = "zip"
    source_dir  = "${path.module}/../src/functions/GetAccount"
    output_path = "${path.module}/exports/lambda/GetAccount.zip"
}

resource "aws_lambda_function" "get_account" {
    function_name = "GetAccount"
    filename      = data.archive_file.get_account_zip.output_path
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
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
    source_dir  = "${path.module}/../src/functions/CreateGame"
    output_path = "${path.module}/exports/lambda/CreateGame.zip"
}

resource "aws_lambda_function" "create_game" {
    function_name = "CreateGame"
    filename      = data.archive_file.create_game_zip.output_path
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 512

    source_code_hash = data.archive_file.create_game_zip.output_base64sha256

    environment {
        variables = {
            GAMES_TABLE = aws_dynamodb_table.games_table.name
            POKER_SERVER_INSTANCE_ID = aws_instance.poker_server.id
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "create_game_logs" {
    name              = "/aws/lambda/CreateGame"
    retention_in_days = 7
}

# --- End CreateGame Lambda Function ---

# --- Start GetGame Lambda Function ---

data "archive_file" "get_game_zip" {
    type        = "zip"
    source_dir  = "${path.module}/../src/functions/GetGame"
    output_path = "${path.module}/exports/lambda/GetGame.zip"
}

resource "aws_lambda_function" "get_game" {
    function_name = "GetGame"
    filename      = data.archive_file.get_game_zip.output_path
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 512

    source_code_hash = data.archive_file.get_game_zip.output_base64sha256

    environment {
        variables = {
            GAMES_TABLE = aws_dynamodb_table.games_table.name
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "get_game_logs" {
    name              = "/aws/lambda/GetGame"
    retention_in_days = 7
}

# --- End GetGame Lambda Function ---

# --- Start UpdateGame Lambda Function ---

data "archive_file" "update_game_zip" {
    type        = "zip"
    source_dir  = "${path.module}/../src/functions/UpdateGame"
    output_path = "${path.module}/exports/lambda/UpdateGame.zip"
}

resource "aws_lambda_function" "update_game" {
    function_name = "UpdateGame"
    filename      = data.archive_file.update_game_zip.output_path
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 512

    source_code_hash = data.archive_file.update_game_zip.output_base64sha256

    environment {
        variables = {
            GAMES_TABLE = aws_dynamodb_table.games_table.name,
            SERVER_SECRET_TOKEN = random_password.server_api_token.result
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "update_game_logs" {
    name              = "/aws/lambda/UpdateGame"
    retention_in_days = 7
}

# --- End UpdateGame Lambda Function ---