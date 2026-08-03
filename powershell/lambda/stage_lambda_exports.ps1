# Get all function directory names from ./src/functions
$functions = Get-ChildItem -Path "./src/functions" -Directory | Select-Object -ExpandProperty Name

foreach ($functionDirName in $functions) {

    # if ($functionName -and $functionName -ne functionDirName) {
    #     continue;
    # }

    if ( (Test-Path "Variable:functionName") -and ($functionName -ne $functionDirName) ) {
        continue;
    }

    Write-Host "Staging Lambda function: $functionDirName" -ForegroundColor Cyan

    # Clean & recreate the function's staging directory
    if (Test-Path $StageDir) { 
        Remove-Item -Recurse -Force $StageDir 
    }
    New-Item -ItemType Directory -Path "$StageDir/shared" -Force | Out-Null
    New-Item -ItemType Directory -Path "$StageDir/node_modules" -Force | Out-Null

    # Copy the Lambda handler and shared Proto file. Handles all file endings
    $handlerFile = Get-ChildItem -Path "src/functions/$functionDirName" -Filter "index.*" | Select-Object -First 1
    if ($handlerFile) {
        Copy-Item $handlerFile.FullName "$StageDir/$($handlerFile.Name)"
    } else {
        Write-Warning "No index file found for $functionDirName!"
    }
   
    Copy-Item "shared/poker_api.proto" "$StageDir/shared/poker_api.proto"

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
}

Write-Host "All functions staged successfully in exports/lambda/!" -ForegroundColor Green