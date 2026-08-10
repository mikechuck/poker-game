# Force PowerShell as the default shell runner
set shell := ["pwsh", "-ExecutionPolicy", "Bypass", "-Command"]

# Variables
tf_dir := "terraform"

# Commands
default:
    @just --list

# Generates godot protobuf files
generate-proto:
    ./powershell/generate_proto.ps1

# Stages and zips files for lambda exports
stage-lambda-exports function_name="": 
    just generate-proto
    ./powershell/lambda/stage_lambda_exports.ps1 -functionName "{{function_name}}"

# Uploads lambda function to aws. Params: function_name (optional) lambda function name
upload-lambda-functions function_name="": (stage-lambda-exports function_name)
    ./powershell/lambda/upload_function.ps1 -functionName "{{function_name}}"

# Deploy Game Server. Params: env (optional) takes dev or prod
upload-server-files env="dev": generate-proto
    ./powershell/server/export_linux_server.ps1 -env "{{env}}"
    node aws/upload_server_s3_files.cjs

# Deploy Frontend. Params: env (optional) takes dev or prod
deploy-frontend env="dev": generate-proto
    ./powershell/web/export_web.ps1 -env "{{env}}"
    node aws/deploy_frontend.cjs {{env}}

# Deplopy server files to S3
deploy-server-files env="dev": generate-proto
    ./powershell/server/export_linux_server.ps1 -env "{{env}}"
    node aws/upload_server_s3_files.cjs {{env}}

# Plan terraform without deploying
plan-terraform: generate-proto stage-lambda-exports
    cd {{tf_dir}} && terraform plan

# Full Deployment Pipeline. Params: env (optional) takes dev or prod
full-deploy env="dev": upload-lambda-functions (deploy-frontend env)
    cd {{tf_dir}} && terraform apply -auto-approve -replace="aws_instance.poker_server"