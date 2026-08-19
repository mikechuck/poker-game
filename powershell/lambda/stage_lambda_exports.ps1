param (
    [string]$functionName = ""
)

# Get all function directory names from ./src/functions
$functions = Get-ChildItem -Path "./src/functions" -Directory | Select-Object -ExpandProperty Name

foreach ($functionDirName in $functions) {
    if ( ($functionName -ne "") -and ($functionName -ne $functionDirName) ) {
        Write-Host "Skipping staging for $functionDirName"
        continue;
    }

    Write-Host "Staging Lambda function: $functionDirName" -ForegroundColor Cyan
    $StageDir     = "exports/lambda/$functionDirName"

    # Clean & recreate the function's staging directory
    if (Test-Path $StageDir) { 
        Remove-Item -Recurse -Force $StageDir 
    }

    New-Item -ItemType Directory -Path "$StageDir/shared" -Force | Out-Null
    New-Item -ItemType Directory -Path "$StageDir/node_modules" -Force | Out-Null

    # Copy the Lambda handler and shared Proto file. Handles all file endings
    $handlerFile = Get-ChildItem -Path "src/functions/$functionDirName" -Filter "index.mjs*" | Select-Object -First 1
    if ($handlerFile) {
        # Edge authorizers can't use environment variables, need to export it is as a template
        # file so that terraform can inject variables properly
        if ($functionDirName -eq "ServerEdgeAuthorizer") {
            Copy-Item $handlerFile.FullName "$StageDir/$($handlerFile.Name).tpl"
        } else {
            Copy-Item $handlerFile.FullName "$StageDir/$($handlerFile.Name)"
        }
    } else {
        Write-Warning "No index file found for $functionDirName!"
    }
   
    Copy-Item "shared/poker_api.proto" "$StageDir/shared/poker_api.proto"
    Copy-Item "shared/utilities.mjs" "$StageDir/shared/utilities.mjs"

    # Copy protobufjs & required scoped dependencies from root node_modules
    if (Test-Path "node_modules/protobufjs") {
        Copy-Item -Recurse "node_modules/protobufjs" "$StageDir/node_modules/protobufjs"
    }

    if (Test-Path "node_modules/@protobufjs") {
        Copy-Item -Recurse "node_modules/@protobufjs" "$StageDir/node_modules/@protobufjs"
    }

    if (Test-Path "node_modules/long") {
        Copy-Item -Recurse "node_modules/long" "$StageDir/node_modules/long"
    }

    # Zip lambda files
    $zipPath = "exports/lambda/$functionDirName.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$stageDir/*" -DestinationPath $zipPath -Force
}

Write-Host "All functions staged in exports/lambda directory" -ForegroundColor Green