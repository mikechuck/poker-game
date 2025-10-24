# Detect operating system
$OS = $PSVersionTable.OS

if ($OS -like "*Windows*") {
    npx http-server exports/web -p 5173 --proxy http://localhost:5173?
} elseif ($OS -like "*Darwin*") { # macOS
    npx http-server exports/web -p 5173 --proxy http://localhost:5173?
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}
