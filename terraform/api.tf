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
    description = "Allows poker lambdas to read/write to DynamoDB tables and indexes"

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
                    "${aws_dynamodb_table.accounts_table.arn}/index/*",

                    aws_dynamodb_table.debts_table.arn,
                    "${aws_dynamodb_table.debts_table.arn}/index/*",

                    aws_dynamodb_table.games_table.arn,
                    "${aws_dynamodb_table.games_table.arn}/index/*",

                    aws_dynamodb_table.join_tokens_table.arn,
                    "${aws_dynamodb_table.join_tokens_table.arn}/index/*",

                    aws_dynamodb_table.relationships_table.arn,
                    "${aws_dynamodb_table.relationships_table.arn}/index/*"
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

resource "aws_apigatewayv2_route" "server_get_account_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "GET /server/account/{accountId}"
    target    = "integrations/${aws_apigatewayv2_integration.get_account_int.id}"
    authorization_type = "CUSTOM"
    authorizer_id      = aws_apigatewayv2_authorizer.server_token_auth.id
}

# Grant Permission for API Gateway to invoke the Lambda
resource "aws_lambda_permission" "api_gw_get_account" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.get_account.function_name
    principal     = "apigateway.amazonaws.com"

    # Standard security: restrict access to your specific API
    source_arn = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*"
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

# --- Start JoinGame API Gateway Integration ---

resource "aws_apigatewayv2_integration" "join_game_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.join_game.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "join_game_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "POST /game/{gameId}/join"

    target             = "integrations/${aws_apigatewayv2_integration.join_game_int.id}"
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

resource "aws_lambda_permission" "api_gw_join_game" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.join_game.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*/game/*/join"
}

# --- End JoinGame API Gateway Integration ---

# --- Start GetGame API Gateway Integration ---

resource "aws_apigatewayv2_integration" "get_game_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.get_game.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_game_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "GET /game/{gameId}"

    target             = "integrations/${aws_apigatewayv2_integration.get_game_int.id}"
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

resource "aws_lambda_permission" "api_gw_get_game" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.get_game.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*/game/*"
}

# --- End GetGame API Gateway Integration ---

# --- Start GetGames API Gateway Integration ---

resource "aws_apigatewayv2_integration" "get_games_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.get_games.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_games_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "GET /games"

    target             = "integrations/${aws_apigatewayv2_integration.get_games_int.id}"
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

resource "aws_lambda_permission" "api_gw_get_games" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.get_games.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*/games"
}

# --- End GetGames API Gateway Integration ---

# --- Start Server UpdateGame API Gateway Integration ---

resource "aws_apigatewayv2_integration" "server_update_game_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.update_game.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "server_update_game_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "POST /server/game/{gameId}"
    target    = "integrations/${aws_apigatewayv2_integration.server_update_game_int.id}"
    authorization_type = "CUSTOM"
    authorizer_id      = aws_apigatewayv2_authorizer.server_token_auth.id
}

resource "aws_lambda_permission" "api_gw_server_update_game" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.update_game.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*/*/game/*"
}

# --- End Server UpdateGame API Gateway Integration ---

# --- Start AddFriend API Gateway Integration ---

# Create the Integration
resource "aws_apigatewayv2_integration" "add_friend_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.add_friend.invoke_arn
    payload_format_version = "2.0"
}

# Update the existing Route to point to this integration
resource "aws_apigatewayv2_route" "add_friend_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "POST /friends/request"

    target             = "integrations/${aws_apigatewayv2_integration.add_friend_int.id}"
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

# Grant Permission for API Gateway to invoke the Lambda
resource "aws_lambda_permission" "api_gw_add_friend" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.add_friend.function_name
    principal     = "apigateway.amazonaws.com"

    # Standard security: restrict access to your specific API
    source_arn = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*"
}

# --- End AddFriend API Gateway Integration ---

# --- Start GetFriends API Gateway Integration ---

# Create the Integration
resource "aws_apigatewayv2_integration" "get_friends_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.get_friends.invoke_arn
    payload_format_version = "2.0"
}

# Update the existing Route to point to this integration
resource "aws_apigatewayv2_route" "get_friends_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "GET /friends"

    target             = "integrations/${aws_apigatewayv2_integration.get_friends_int.id}"
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

# Grant Permission for API Gateway to invoke the Lambda
resource "aws_lambda_permission" "api_gw_get_friends" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.get_friends.function_name
    principal     = "apigateway.amazonaws.com"

    # Standard security: restrict access to your specific API
    source_arn = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*"
}

# --- End GetFriends API Gateway Integration ---

# --- Start AcceptFriend API Gateway Integration ---

# Create the Integration
resource "aws_apigatewayv2_integration" "accept_friend_int" {
    api_id           = aws_apigatewayv2_api.poker_api.id
    integration_type = "AWS_PROXY"
    integration_uri  = aws_lambda_function.accept_friend.invoke_arn
    payload_format_version = "2.0"
}

# Update the existing Route to point to this integration
resource "aws_apigatewayv2_route" "accept_friend_route" {
    api_id    = aws_apigatewayv2_api.poker_api.id
    route_key = "POST /friends/{requestorAccountId}/accept"

    target             = "integrations/${aws_apigatewayv2_integration.accept_friend_int.id}"
    authorization_type = "JWT"
    authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

# Grant Permission for API Gateway to invoke the Lambda
resource "aws_lambda_permission" "api_gw_accept_friend" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.accept_friend.function_name
    principal     = "apigateway.amazonaws.com"

    # Standard security: restrict access to your specific API
    source_arn = "${aws_apigatewayv2_api.poker_api.execution_arn}/*/*"
}

# --- End AcceptFriend API Gateway Integration ---

# --- Start Private Server Authorizer Lambda Function ---

resource "aws_lambda_function" "server_auth_lambda" {
    function_name = "ServerAuthorizer"
    filename      = "${path.module}/../exports/lambda/ServerAuthorizer.zip"
    role          = aws_iam_role.authorizer_lambda_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x"
    timeout       = 5
    memory_size   = 128
    provider      = aws.us_east_1
    publish       = true

    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/ServerAuthorizer.zip")

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

resource "aws_lambda_function" "get_account" {
    function_name = "GetAccount"
    filename      = "${path.module}/../exports/lambda/GetAccount.zip"
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 128

    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/GetAccount.zip")

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

resource "aws_lambda_function" "create_game" {
    function_name = "CreateGame"
    filename      = "${path.module}/../exports/lambda/CreateGame.zip"
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 512

    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/CreateGame.zip")

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

# --- Start JoinGame Lambda Function ---

resource "aws_lambda_function" "join_game" {
    function_name = "JoinGame"
    filename      = "${path.module}/../exports/lambda/JoinGame.zip"
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 512

    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/JoinGame.zip")

    environment {
        variables = {
            GAMES_TABLE = aws_dynamodb_table.games_table.name,
            JOIN_TOKENS_TABLE = aws_dynamodb_table.join_tokens_table.name
            RELATIONSHIPS_TABLE = aws_dynamodb_table.relationships_table.name
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "join_game_logs" {
    name              = "/aws/lambda/JoinGame"
    retention_in_days = 7
}

# --- End GetGame Lambda Function ---

# --- Start GetGame Lambda Function ---

resource "aws_lambda_function" "get_game" {
    function_name = "GetGame"
    filename      = "${path.module}/../exports/lambda/GetGame.zip"
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 512

    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/GetGame.zip")

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

# --- Start GetGames Lambda Function ---

resource "aws_lambda_function" "get_games" {
    function_name = "GetGames"
    filename      = "${path.module}/../exports/lambda/GetGames.zip"
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 512

    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/GetGames.zip")

    environment {
        variables = {
            GAMES_TABLE = aws_dynamodb_table.games_table.name
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "get_games_logs" {
    name              = "/aws/lambda/GetGames"
    retention_in_days = 7
}

# --- End GetGames Lambda Function ---

# --- Start UpdateGame Lambda Function ---

resource "aws_lambda_function" "update_game" {
    function_name = "UpdateGame"
    filename      = "${path.module}/../exports/lambda/UpdateGame.zip"
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 512

    # Forces redeployment only if zip contents change
    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/UpdateGame.zip")

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

# --- Start AddFriend Lambda Function ---

resource "aws_lambda_function" "add_friend" {
    function_name = "AddFriend"
    filename      = "${path.module}/../exports/lambda/AddFriend.zip"
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 128

    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/AddFriend.zip")

    environment {
        variables = {
            ACCOUNTS_TABLE = aws_dynamodb_table.accounts_table.name
            RELATIONSHIPS_TABLE = aws_dynamodb_table.relationships_table.name
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "add_friend_logs" {
    name              = "/aws/lambda/AddFriend"
    retention_in_days = 7
}

# --- End AddFriend Lambda Function ---

# --- Start GetFriends Lambda Function ---

resource "aws_lambda_function" "get_friends" {
    function_name = "GetFriends"
    filename      = "${path.module}/../exports/lambda/GetFriends.zip"
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 128

    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/GetFriends.zip")

    environment {
        variables = {
            RELATIONSHIPS_TABLE = aws_dynamodb_table.relationships_table.name
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "get_friends_logs" {
    name              = "/aws/lambda/GetFriends"
    retention_in_days = 7
}

# --- End GetFriends Lambda Function ---

# --- Start AcceptFriend Lambda Function ---

resource "aws_lambda_function" "accept_friend" {
    function_name = "AcceptFriend"
    filename      = "${path.module}/../exports/lambda/AcceptFriend.zip"
    role          = aws_iam_role.lambda_integration_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x" # Node 22 is the standard current LTS
    timeout       = 10
    memory_size   = 128

    source_code_hash = filebase64sha256("${path.module}/../exports/lambda/AcceptFriend.zip")

    environment {
        variables = {
            RELATIONSHIPS_TABLE = aws_dynamodb_table.relationships_table.name
        }
    }
}

# Create the log group explicitly to control retention
resource "aws_cloudwatch_log_group" "accept_friend_logs" {
    name              = "/aws/lambda/AcceptFriend"
    retention_in_days = 7
}

# --- End AcceptFriend Lambda Function ---