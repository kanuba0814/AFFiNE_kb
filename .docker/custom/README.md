# AFFiNE Custom Build - Podman Deployment

This directory contains everything needed to build and deploy your customized AFFiNE fork with Podman.

## Quick Start

### Option 1: Automated Build (Recommended)

```bash
# From project root, run the build script
./.docker/custom/build.sh

# Then deploy
cd .docker/custom
cp .env.example .env
# Edit .env with your settings
podman-compose up -d
```

### Option 2: Manual Build

```bash
# 1. Build the project (from project root)
yarn install
yarn affine @affine/native build
yarn affine @affine/server-native build
yarn build

# 2. Build the container image
podman build -f .docker/custom/Dockerfile -t localhost/affine-custom:latest .

# 3. Deploy
cd .docker/custom
cp .env.example .env
# Edit .env with your settings
podman-compose up -d
```

## Files in This Directory

- **`Dockerfile`** - Container image definition
- **`compose.yml`** - Podman Compose service definitions
- **`.env.example`** - Environment configuration template
- **`build.sh`** - Automated build script
- **`README.md`** - This file

## Configuration

Edit `.env` file to configure:

- `PORT` - Port to expose (default: 3010)
- `AFFINE_SERVER_HOST` - Your domain or IP
- `DB_DATA_LOCATION` - PostgreSQL data directory (use absolute path)
- `UPLOAD_LOCATION` - File uploads directory (use absolute path)
- `CONFIG_LOCATION` - Configuration directory (use absolute path)
- `DB_PASSWORD` - Database password (change for production!)

## Deployment Commands

```bash
# Start services
podman-compose up -d

# View logs
podman-compose logs -f

# Stop services
podman-compose down

# Restart a service
podman-compose restart affine

# Rebuild and redeploy
podman-compose down
./.docker/custom/build.sh
podman-compose up -d
```

## Accessing AFFiNE

After deployment, access AFFiNE at:
- **Local**: http://localhost:3010
- **Network**: http://your-server-ip:3010

The first user to register becomes the administrator.

## Custom Features

This build includes these modifications for personal use:

- ✅ 10GB frontend file upload limit (vs 2GB official)
- ✅ 1GB backend file upload limit (vs 100MB official)
- ✅ 5-minute upload timeout (vs 15 seconds official)
- ✅ 999 member limit per workspace (vs 3-10 official)
- ✅ 10TB storage quota (vs 10-100GB official)
- ✅ 1-year history retention (vs 7-30 days official)
- ✅ Removed "Download App" and "Learn more" UI prompts

## Troubleshooting

See the comprehensive [PODMAN_DEPLOY.md](../../PODMAN_DEPLOY.md) guide in the project root for:
- Detailed build instructions
- Production setup recommendations
- Backup and restore procedures
- Common issues and solutions

## ⚠️ Important Notice

**FOR PERSONAL USE ONLY** - These modifications are not intended for commercial deployment. See [README.md](../../README.md) for license information.
