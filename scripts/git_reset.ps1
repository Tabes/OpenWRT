Write-Host "=== Git Repository Reset Script ===" -ForegroundColor Green
Write-Host "This will completely reset your Git history and create a fresh repository." -ForegroundColor Yellow
Write-Host ""

# Confirm execution
$confirmation = Read-Host "Are you sure you want to proceed? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Operation cancelled." -ForegroundColor Red
    exit 1
}

Write-Host "Step 1: Removing old Git history..." -ForegroundColor Cyan
Remove-Item -Recurse -Force .git -ErrorAction SilentlyContinue

Write-Host "Step 2: Initializing new Git repository..." -ForegroundColor Cyan
git init

Write-Host "Step 3: Adding remote origin..." -ForegroundColor Cyan
git remote add origin https://github.com/Tabes/OpenWRT.git

Write-Host "Step 4: Adding all files (respecting .gitignore)..." -ForegroundColor Cyan
git add .

Write-Host "Step 5: Creating initial commit..." -ForegroundColor Cyan
git commit -m "Fresh start - removed large files"

Write-Host "Step 6: Force pushing to GitHub..." -ForegroundColor Cyan
git push origin main --force

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Green
Write-Host "Your repository has been reset and pushed to GitHub." -ForegroundColor Green
Write-Host "Large files should now be excluded by .gitignore." -ForegroundColor Green