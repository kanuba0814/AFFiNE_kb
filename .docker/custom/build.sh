#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  AFFiNE Custom Build Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}Error: Must run this script from the AFFiNE project root${NC}"
    echo -e "${YELLOW}Usage: .docker/custom/build.sh${NC}"
    exit 1
fi

# Check for required tools
command -v node >/dev/null 2>&1 || { echo -e "${RED}Error: Node.js is required but not installed${NC}"; exit 1; }
command -v yarn >/dev/null 2>&1 || { echo -e "${RED}Error: Yarn is required but not installed${NC}"; exit 1; }
command -v podman >/dev/null 2>&1 || { echo -e "${RED}Error: Podman is required but not installed${NC}"; exit 1; }

echo -e "${YELLOW}Step 1/5: Installing dependencies...${NC}"
yarn install

echo ""
echo -e "${YELLOW}Step 2/5: Building native dependencies...${NC}"
yarn affine @affine/native build
yarn affine @affine/server-native build

echo ""
echo -e "${YELLOW}Step 3/5: Building project...${NC}"
export NODE_OPTIONS="--max-old-space-size=8192"
yarn build

echo ""
echo -e "${YELLOW}Step 4/5: Building Podman image...${NC}"
podman build \
  -f .docker/custom/Dockerfile \
  -t localhost/affine-custom:latest \
  .

echo ""
echo -e "${YELLOW}Step 5/5: Verifying image...${NC}"
podman images | grep affine-custom

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "To deploy, run:"
echo -e "${YELLOW}  cd .docker/custom${NC}"
echo -e "${YELLOW}  cp .env.example .env${NC}"
echo -e "${YELLOW}  # Edit .env file with your settings${NC}"
echo -e "${YELLOW}  podman-compose up -d${NC}"
echo ""
