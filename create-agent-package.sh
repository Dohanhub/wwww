#!/bin/bash
# This script creates a deployment package for the AI agent platform

echo "Creating agent platform deployment package..."

# Define paths
CURRENT_DIR=$(pwd)
AGENT_DIR="${CURRENT_DIR}/domains/agent-platform"
DEPLOYMENT_DIR="${CURRENT_DIR}/deployment"
PACKAGE_NAME="ai-agent-platform-$(date +%Y%m%d-%H%M%S).zip"

# Create deployment directory if it doesn't exist
mkdir -p "${DEPLOYMENT_DIR}"

# Navigate to agent platform directory
cd "${AGENT_DIR}" || { echo "Error: Agent platform directory not found"; exit 1; }

# Create a clean distribution
echo "Cleaning up temporary files..."
find . -type d -name __pycache__ -exec rm -rf {} +
find . -type f -name "*.pyc" -delete
find . -type f -name "*.pyo" -delete
find . -type f -name "*.log" -delete

# Create package
echo "Creating zip package..."
zip -r "${DEPLOYMENT_DIR}/${PACKAGE_NAME}" . -x "*.git*" "*.env" "*__pycache__*" "*.pytest_cache*" "*.venv*" "*.idea*" "*.vscode*"

# Return to original directory
cd "${CURRENT_DIR}" || exit

echo "AI Agent Platform package created: ${DEPLOYMENT_DIR}/${PACKAGE_NAME}"
echo ""
echo "To deploy this package:"
echo "1. Unzip the package on your server"
echo "2. Copy .env.example to .env and update with your settings"
echo "3. Run: docker build -t doganhub-agent-platform ."
echo "4. Run: docker run -p 8000:8000 --env-file .env doganhub-agent-platform"
echo ""
echo "Done!"
