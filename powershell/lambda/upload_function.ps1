param (
    [string]$functionName
)

# Script must be run from the root of the project
$SrcDir       = "src/functions/$functionName"
$SharedFile   = "shared/poker_api.proto"
$ZipPath      = "exports/lambda/$functionName.zip"
$StageDir     = "exports/lambda/stage_$functionName"

Write-Host "📦 Preparing deployment package layout for $functionName..."

& "$PSScriptRoot\stage_lambda_exports.ps1"

Write-Host "🗜️ Zipping staged code into $ZipPath..."

Compress-Archive -Path "$StageDir/*" -DestinationPath $ZipPath -Force

Remove-Item $StageDir -Recurse -Force

Write-Host "🚀 Uploading payload to AWS Lambda ($functionName)..."

aws lambda update-function-code `
    --function-name $functionName `
    --zip-file "fileb://$ZipPath" `
    --no-cli-pager

Write-Host "✅ Deployment successful!"