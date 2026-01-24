#!/bin/bash
# ============================================
# STREAMFLIX - Load Environment Variables
# ============================================
# Run this script before starting the application
# Usage: source ./scripts/load-env.sh
# ============================================

ENV_FILE="${1:-.env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE_PATH="$PROJECT_ROOT/$ENV_FILE"

if [ ! -f "$ENV_FILE_PATH" ]; then
    echo -e "\033[31mERROR: .env file not found at $ENV_FILE_PATH\033[0m"
    echo -e "\033[33mPlease copy .env.example to .env and fill in your values\033[0m"
    echo -e "\033[36m  cp .env.example .env\033[0m"
    return 1 2>/dev/null || exit 1
fi

echo -e "\033[32mLoading environment variables from $ENV_FILE_PATH...\033[0m"

# Export variables
set -a
source "$ENV_FILE_PATH"
set +a

echo -e "\033[32mEnvironment variables loaded successfully!\033[0m"
echo ""
echo -e "\033[33mYou can now run:\033[0m"
echo -e "\033[36m  mix phx.server\033[0m"
