#!/bin/bash

# ========================================
# GitHub Actions Build & Deploy Script
# ========================================
# Script ini akan:
# 1. Push code ke GitHub
# 2. Wait untuk GitHub Actions selesai build
# 3. Download binary dari GitHub Artifacts
# 4. Deploy ke service lokal
# ========================================

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_OWNER="${GITHUB_REPO_OWNER:-$(git config --get remote.origin.url | sed -n 's/.*github.com[:/]\([^/]*\)\/.*/\1/p')}"
REPO_NAME="${GITHUB_REPO_NAME:-$(basename -s .git $(git config --get remote.origin.url))}"
BRANCH="${GITHUB_BRANCH:-main}"
SERVICE_NAME="request-bin.service"
BINARY_NAME="rust-request-bin"
INSTALL_PATH="/usr/local/bin/${BINARY_NAME}"

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  GitHub Actions Build & Deploy${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Not a git repository${NC}"
    exit 1
fi

# Check if there are changes to commit
if [[ -z $(git status -s) ]]; then
    echo -e "${YELLOW}⚠️  No changes to commit${NC}"
    read -p "Push anyway to trigger build? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    # Add all changes
    echo -e "${BLUE}📝 Adding changes...${NC}"
    git add .
    
    # Commit with timestamp
    COMMIT_MSG="${1:-Auto-deploy $(date +'%Y-%m-%d %H:%M:%S')}"
    echo -e "${BLUE}💾 Committing: ${COMMIT_MSG}${NC}"
    git commit -m "$COMMIT_MSG"
fi

# Push to GitHub
echo -e "${BLUE}🚀 Pushing to GitHub...${NC}"
git push origin "$BRANCH"

# Get the commit SHA
COMMIT_SHA=$(git rev-parse HEAD)
SHORT_SHA=$(git rev-parse --short HEAD)
echo -e "${GREEN}✅ Pushed commit: ${SHORT_SHA}${NC}"
echo ""

# Wait for GitHub Actions to start
echo -e "${BLUE}⏳ Waiting for GitHub Actions to start...${NC}"
sleep 10

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI (gh) not found${NC}"
    echo -e "${YELLOW}   Install with: sudo apt install gh${NC}"
    echo -e "${YELLOW}   Or download binary manually from:${NC}"
    echo -e "${YELLOW}   https://github.com/${REPO_OWNER}/${REPO_NAME}/actions${NC}"
    echo ""
    read -p "Continue with manual download? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    MANUAL_MODE=true
else
    MANUAL_MODE=false
fi

if [ "$MANUAL_MODE" = false ]; then
    # Wait for workflow to complete
    echo -e "${BLUE}⏳ Waiting for build to complete...${NC}"
    echo -e "${YELLOW}   This may take 2-5 minutes...${NC}"
    
    # Monitor workflow status
    WORKFLOW_ID=""
    MAX_WAIT=600  # 10 minutes
    ELAPSED=0
    
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        # Get latest workflow run
        WORKFLOW_STATUS=$(gh run list --limit 1 --json status,conclusion,databaseId --jq '.[0]')
        
        if [ -n "$WORKFLOW_STATUS" ]; then
            STATUS=$(echo "$WORKFLOW_STATUS" | jq -r '.status')
            CONCLUSION=$(echo "$WORKFLOW_STATUS" | jq -r '.conclusion')
            WORKFLOW_ID=$(echo "$WORKFLOW_STATUS" | jq -r '.databaseId')
            
            if [ "$STATUS" = "completed" ]; then
                if [ "$CONCLUSION" = "success" ]; then
                    echo -e "${GREEN}✅ Build completed successfully!${NC}"
                    break
                else
                    echo -e "${RED}❌ Build failed with conclusion: ${CONCLUSION}${NC}"
                    echo -e "${YELLOW}   Check logs: gh run view ${WORKFLOW_ID}${NC}"
                    exit 1
                fi
            else
                echo -e "${YELLOW}   Status: ${STATUS}...${NC}"
            fi
        fi
        
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    
    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo -e "${RED}❌ Timeout waiting for build${NC}"
        exit 1
    fi
    
    # Download artifact
    echo -e "${BLUE}📥 Downloading binary artifact...${NC}"
    
    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download latest artifact
    gh run download --repo "${REPO_OWNER}/${REPO_NAME}" --name "${BINARY_NAME}-latest"
    
    if [ ! -f "$BINARY_NAME" ]; then
        echo -e "${RED}❌ Binary not found in artifact${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Make binary executable
    chmod +x "$BINARY_NAME"
    
    echo -e "${GREEN}✅ Binary downloaded${NC}"
    ls -lh "$BINARY_NAME"
    
else
    # Manual mode
    echo -e "${YELLOW}📥 Manual Download Mode${NC}"
    echo -e "${YELLOW}   1. Go to: https://github.com/${REPO_OWNER}/${REPO_NAME}/actions${NC}"
    echo -e "${YELLOW}   2. Find the latest successful workflow run${NC}"
    echo -e "${YELLOW}   3. Download '${BINARY_NAME}-latest' artifact${NC}"
    echo -e "${YELLOW}   4. Extract and place binary in: /tmp/${BINARY_NAME}${NC}"
    echo ""
    read -p "Press Enter when binary is ready in /tmp/${BINARY_NAME}..."
    
    TEMP_DIR="/tmp"
    if [ ! -f "/tmp/${BINARY_NAME}" ]; then
        echo -e "${RED}❌ Binary not found at /tmp/${BINARY_NAME}${NC}"
        exit 1
    fi
    
    chmod +x "/tmp/${BINARY_NAME}"
fi

# Deploy binary
echo ""
echo -e "${BLUE}🔄 Deploying binary...${NC}"

# Stop service
echo -e "${YELLOW}⏸️  Stopping service...${NC}"
sudo systemctl stop "$SERVICE_NAME"

# Backup current binary
if [ -f "$INSTALL_PATH" ]; then
    BACKUP_PATH="${INSTALL_PATH}.backup.$(date +%s)"
    echo -e "${BLUE}💾 Backing up current binary to: ${BACKUP_PATH}${NC}"
    sudo cp "$INSTALL_PATH" "$BACKUP_PATH"
fi

# Install new binary
echo -e "${BLUE}📦 Installing new binary...${NC}"
sudo cp "${TEMP_DIR}/${BINARY_NAME}" "$INSTALL_PATH"
sudo chmod +x "$INSTALL_PATH"

# Clean up temp directory
if [ "$MANUAL_MODE" = false ]; then
    rm -rf "$TEMP_DIR"
fi

# Start service
echo -e "${BLUE}▶️  Starting service...${NC}"
sudo systemctl start "$SERVICE_NAME"

# Wait a moment for service to start
sleep 2

# Check service status
echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
sudo systemctl status "$SERVICE_NAME" --no-pager | grep -E "Active:|Memory:"

# Check if service is running
if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    echo ""
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}  ✨ Deploy Successful!${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}Service is running at: http://localhost:9997${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}=======================================${NC}"
    echo -e "${RED}  ❌ Deploy Failed!${NC}"
    echo -e "${RED}=======================================${NC}"
    echo -e "${RED}Service failed to start. Check logs:${NC}"
    echo -e "${YELLOW}sudo journalctl -u ${SERVICE_NAME} -n 50${NC}"
    
    # Rollback if backup exists
    if [ -f "$BACKUP_PATH" ]; then
        echo ""
        read -p "Rollback to previous version? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo cp "$BACKUP_PATH" "$INSTALL_PATH"
            sudo systemctl start "$SERVICE_NAME"
            echo -e "${GREEN}✅ Rolled back to previous version${NC}"
        fi
    fi
    
    exit 1
fi
