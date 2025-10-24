# Detect operating system
$OS = $PSVersionTable.OS

if ($OS -like "*Windows*") {
    python -m http.server 8080 --directory exports/web
} elseif ($OS -like "*Darwin*") { # macOS
    python3 -m http.server 8080 --directory exports/web
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}
