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

resource "aws_iam_role_policy" "ec2_ssm_parameter_access" {
    name = "poker-ec2-ssm-parameter-policy"
    role = aws_iam_role.ec2_logs_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "ssm:GetParameter",
                    "ssm:GetParameters"
                ]
                # Restrict access precisely to your cloudwatch config parameter resource
                Resource = [
                    aws_ssm_parameter.cw_agent_config.arn,
                    aws_ssm_parameter.server_api_token.arn
                ]
            },
            {
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogStreams",
                    "logs:DescribeLogGroups"
                ]
                # Restrict permissions directly to your specific node app log group path
                Resource = [
                    "*"
                ]
            }
        ]
    })
}

resource "aws_iam_role_policy" "ec2_s3_bucket_access" {
  name = "poker-ec2-s3-bucket-policy"
  role = aws_iam_role.ec2_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::chuckycodes-games",
          "arn:aws:s3:::chuckycodes-games/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_dynamo_update_access" {
    name = "poker-ec2-dynamo-update-policy"
    role = aws_iam_role.ec2_logs_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "dynamodb:UpdateItem"
                ]
                Resource = [
                    aws_dynamodb_table.games_table.arn 
                ]
            }
        ]
    })
}

# --- Start Lambda Edge Config ---

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
    output_path = "${path.module}/exports/lambda/auth_edge.zip"
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
        gamesTableName    = aws_dynamodb_table.games_table.name
    })
}

resource "aws_instance" "poker_server" {
    ami                    = "ami-0341d95f75f311023"
    instance_type          = "t3.micro"
    iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
    vpc_security_group_ids = [aws_security_group.poker_sg.id]
    user_data              = local.user_data
    user_data_replace_on_change = true

    tags = {
        Name = "PokerGameServer"
    }
}

resource "aws_eip" "poker_server_eip" {
  instance = aws_instance.poker_server.id
  domain   = "vpc"
  tags = { Name = "PokerServerEIP" }
}

resource "aws_security_group" "poker_sg" {
    name        = "poker-game-sg"
    description = "Nginx front door"

    ingress {
        from_port   = 8000
        to_port     = 8000
        protocol    = "tcp"
        security_groups = [aws_security_group.alb_sg.id]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
# --- End EC2 Instance Config ---

# --- Start logging ---

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
                            file_path       = "/home/ec2-user/logs/orchestrator.log"
                            log_group_name  = "/apps/poker-game"
                            log_stream_name = "{instance_id}-orchestrator"
                        }
                    ]
                }
            }
        }
    })
}

# --- End logging ---