param (
    [string]$functionName
)

# Script must be run from the root of the project
$SharedFile = "shared/poker_api.proto"
$functions = Get-ChildItem -Path "./src/functions" -Directory | Select-Object -ExpandProperty Name

foreach ($functionDirName in $functions) {
    if ( ($functionName -ne "") -and ($functionName -ne $functionDirName) ) {
        continue;
    }

    if ($functionDirName -eq "ServerEdgeAuthorizer") {
        Write-Host "Skipping ServerEdgeAuthorizer, can only be deployed from terraform" -ForegroundColor Yellow
        continue;
    }

    $SrcDir       = "src/functions/$functionDirName"
    $ZipPath      = "exports/lambda/$functionDirName.zip"
    $StageDir     = "exports/lambda/$functionDirName"

    Write-Host "Preparing deployment package layout for $functionDirName..." -ForegroundColor Cyan

    Compress-Archive -Path "$StageDir/*" -DestinationPath $ZipPath -Force

    Remove-Item $StageDir -Recurse -Force

    Write-Host "Uploading payload to AWS Lambda ($functionDirName)..." -ForegroundColor Cyan

    aws lambda update-function-code `
        --function-name $functionDirName `
        --zip-file "fileb://$ZipPath" `
        --no-cli-pager `
        > $null

    Write-Host "Deployment to $functionDirName successful." -ForegroundColor Green
}