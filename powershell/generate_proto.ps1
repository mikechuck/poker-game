# Generate all protobuf contracts before exporting
$env:PROTOC_GEN_GDSCRIPT_PREFIX="res://scripts/network/"
protoc --gdscript_out=./scripts/network -I . ./shared/poker_api.proto

# Need to add this ignore to the file, the generator doesn't take into account strict typing settings
$filePath = "./scripts/network/poker_api.proto.gd"
$content = Get-Content $filePath -Raw
Set-Content -Path $filePath -Value "@warning_ignore_start(""unsafe_property_access"", ""unsafe_call_argument"", ""unsafe_method_access"")`n$content"