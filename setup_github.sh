#!/bin/bash

# GitHub Repository Setup Script for AI POS System
echo "🚀 Setting up GitHub repository for AI POS System..."

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated. Please run: gh auth login --web"
    echo "Then run this script again."
    exit 1
fi

echo "✅ GitHub CLI authenticated successfully!"

# Create the repository
echo "📦 Creating GitHub repository..."
REPO_NAME="ai-pos-system"
DESCRIPTION="World-class multi-tenant POS system built with Flutter for modern restaurants"

# Create the repository
gh repo create $REPO_NAME \
    --description "$DESCRIPTION" \
    --public \
    --source=. \
    --remote=origin \
    --push

if [ $? -eq 0 ]; then
    echo "✅ Repository created successfully!"
    echo "🌐 Repository URL: https://github.com/$(gh api user --jq .login)/$REPO_NAME"
    
    # Add topics to the repository
    echo "🏷️ Adding repository topics..."
    gh repo edit --add-topic flutter,dart,pos-system,restaurant,thermal-printing,cross-platform,multi-tenant
    
    # Enable GitHub Pages (optional)
    echo "📄 Setting up GitHub Pages..."
    gh repo edit --enable-pages --pages-source=main
    
    echo ""
    echo "🎉 GitHub repository setup complete!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Visit: https://github.com/$(gh api user --jq .login)/$REPO_NAME"
    echo "2. Review the README and repository settings"
    echo "3. Share the repository with your team"
    echo "4. Set up branch protection rules if needed"
    echo ""
    echo "🔗 Repository URL: https://github.com/$(gh api user --jq .login)/$REPO_NAME"
    
else
    echo "❌ Failed to create repository. Please check your GitHub permissions."
    exit 1
fi 