#!/bin/bash

echo "=== Git Repository Reset Script ==="
echo "This will completely reset your Git history and create a fresh repository."
echo ""

# Confirm execution
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

echo "Step 1: Removing old Git history..."
rm -rf .git

echo "Step 2: Initializing new Git repository..."
git init

echo "Step 3: Adding remote origin..."
git remote add origin https://github.com/Tabes/OpenWRT.git

echo "Step 4: Adding all files (respecting .gitignore)..."
git add .

echo "Step 5: Creating initial commit..."
git commit -m "Fresh start - removed large files"

echo "Step 6: Force pushing to GitHub..."
git push origin main --force

echo ""
echo "=== Done! ==="
echo "Your repository has been reset and pushed to GitHub."
echo "Large files should now be excluded by .gitignore."