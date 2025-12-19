#!/bin/bash
set -e

# Build Docker image using local source code via git archive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_CONTEXT="$PROJECT_ROOT/docker_library/5/bookworm"

echo "Creating source archive from git HEAD..."
cd "$PROJECT_ROOT"
git archive --format=tar.gz HEAD -o "$DOCKER_CONTEXT/ivorysql.tar.gz"

echo "Source archive created: $DOCKER_CONTEXT/ivorysql.tar.gz"
echo "Building Docker image..."
cd "$DOCKER_CONTEXT"
docker build -t ivorysql:5.0-local .

echo "Done! Image built as ivorysql:5.0-local"
