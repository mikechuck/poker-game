param (
    [string]$functionName
)

# Script must be run from the root of the project
$SrcDir       = "src/functions/$functionName"
$ZipPath      = "exports/lambda/$functionName.zip"

Write-Host "📦 Zipping code from $SrcDir into $ZipPath..."

# Clear out any old versions of the zip file so we always have a fresh build
If (Test-Path $ZipPath) { 
    Remove-Item $ZipPath -Force 
}

Compress-Archive -Path "$SrcDir/*" -DestinationPath $ZipPath -Force

Write-Host "🚀 Uploading payload to AWS Lambda ($FunctionName)..."

aws lambda update-function-code `
    --function-name $FunctionName `
    --zip-file "fileb://$ZipPath" `
    --no-cli-pager

Write-Host "✅ Deployment successful!"