if ($IsWindows) {
    npx http-server exports/web -p 5173 --proxy http://localhost:5173?
} elseif ($IsMacOS) {
    npx http-server exports/web -p 5173 --proxy http://localhost:5173?
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}