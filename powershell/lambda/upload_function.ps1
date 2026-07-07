param (
    [string]$functionName
)

# Script must be run from the root of the project
$SrcDir       = "src/functions/$functionName"
$SharedFile   = "shared/enums.json"
$ZipPath      = "exports/lambda/$functionName.zip"
$StageDir     = "exports/lambda/stage_$functionName"

Write-Host "📦 Preparing deployment package layout for $functionName..."

# Cleanup old staging directory
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }

# Setup
New-Item -ItemType Directory -Path "$StageDir/shared" -Force | Out-Null
Copy-Item -Path "$SrcDir/*" -Destination $StageDir -Recurse -Force

if (Test-Path $SharedFile) {
    Copy-Item -Path $SharedFile -Destination "$StageDir/shared/" -Force
} else {
    Write-Error "❌ Error: Could not find shared file at $SharedFile"
    exit 1
}

Write-Host "🗜️ Zipping staged code into $ZipPath..."

Compress-Archive -Path "$StageDir/*" -DestinationPath $ZipPath -Force

Remove-Item $StageDir -Recurse -Force

Write-Host "🚀 Uploading payload to AWS Lambda ($functionName)..."

aws lambda update-function-code `
    --function-name $functionName `
    --zip-file "fileb://$ZipPath" `
    --no-cli-pager

Write-Host "✅ Deployment successful!"