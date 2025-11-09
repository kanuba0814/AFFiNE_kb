# Building and Deploying AFFiNE with Podman

This guide explains how to build and deploy your customized AFFiNE fork using Podman.

## Prerequisites

- **Podman** installed (rootless or rootful)
- **podman-compose** or **docker-compose** (works with Podman)
- **Node.js** (v20.x or v22.x recommended)
- **Yarn** (v4.x) - Corepack enabled
- **Rust** toolchain (for native dependencies)
- At least **16GB RAM** for building
- **20GB+ free disk space**

## Quick Start (Pre-built Image Method)

If you just want to use the modified configuration without building:

```bash
cd .docker/selfhost
cp .env.example .env
# Edit .env file with your settings
podman-compose up -d
```

**Note**: This uses the official AFFiNE image and won't include your customizations. For custom builds, follow the full guide below.

---

## Full Build and Deploy Guide

### Step 1: Install Prerequisites

#### Install Node.js & Yarn
```bash
# Enable corepack for modern Yarn
corepack enable
corepack prepare yarn@stable --activate

# Verify versions
node --version  # Should be v20.x or v22.x
yarn --version  # Should be 4.x
```

#### Install Rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### Step 2: Build the Project

```bash
# Install dependencies (this may take 10-20 minutes)
yarn install

# Build native dependencies (required for both frontend and backend)
yarn affine @affine/native build
yarn affine @affine/server-native build

# Build the entire project (this may take 20-40 minutes)
yarn build
```

**Common build issues:**
- If you get out-of-memory errors, add: `export NODE_OPTIONS="--max-old-space-size=8192"`
- On macOS, use system `strip` instead of `binutils` strip

### Step 3: Create Dockerfile for Custom Build

Create a file `.docker/custom/Dockerfile`:

```dockerfile
FROM node:22-bookworm-slim

# Copy built backend
COPY ./packages/backend/server /app

# Copy built frontend distributions
COPY ./packages/frontend/apps/web/dist /app/static
COPY ./packages/frontend/admin/dist /app/static/admin
COPY ./packages/frontend/apps/mobile/dist /app/static/mobile

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssl libjemalloc2 && \
    rm -rf /var/lib/apt/lists/*

# Enable jemalloc for better memory performance
ENV LD_PRELOAD=libjemalloc.so.2

# Expose port
EXPOSE 3010

CMD ["node", "./dist/main.js"]
```

### Step 4: Build Container Image with Podman

```bash
# Build the custom image (run from project root)
podman build \
  -f .docker/custom/Dockerfile \
  -t localhost/affine-custom:latest \
  .

# Verify the image was created
podman images | grep affine-custom
```

**Build options:**
- Add `--no-cache` to force a clean build
- Add `--platform linux/amd64` to specify architecture
- Use `--squash` to reduce image size (experimental)

### Step 5: Create Custom Compose File

Create `.docker/custom/compose.yml`:

```yaml
name: affine-custom
services:
  affine:
    image: localhost/affine-custom:latest
    container_name: affine_server
    ports:
      - '${PORT:-3010}:3010'
    depends_on:
      redis:
        condition: service_healthy
      postgres:
        condition: service_healthy
      affine_migration:
        condition: service_completed_successfully
    volumes:
      - ${UPLOAD_LOCATION:-./storage}:/root/.affine/storage
      - ${CONFIG_LOCATION:-./config}:/root/.affine/config
    environment:
      - NODE_ENV=production
      - AFFINE_SERVER_HOST=${AFFINE_SERVER_HOST:-localhost}
      - AFFINE_SERVER_PORT=3010
      - AFFINE_SERVER_HTTPS=${AFFINE_SERVER_HTTPS:-false}
      - DATABASE_URL=postgresql://${DB_USERNAME:-affine}:${DB_PASSWORD:-affine}@postgres:5432/${DB_DATABASE:-affine}
      - REDIS_SERVER_HOST=redis
      - AFFINE_INDEXER_ENABLED=false
    restart: unless-stopped

  affine_migration:
    image: localhost/affine-custom:latest
    container_name: affine_migration_job
    volumes:
      - ${UPLOAD_LOCATION:-./storage}:/root/.affine/storage
      - ${CONFIG_LOCATION:-./config}:/root/.affine/config
    command: ['sh', '-c', 'node ./scripts/self-host-predeploy.js']
    environment:
      - DATABASE_URL=postgresql://${DB_USERNAME:-affine}:${DB_PASSWORD:-affine}@postgres:5432/${DB_DATABASE:-affine}
      - REDIS_SERVER_HOST=redis
      - AFFINE_INDEXER_ENABLED=false
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  redis:
    image: docker.io/library/redis:latest
    container_name: affine_redis
    healthcheck:
      test: ['CMD', 'redis-cli', '--raw', 'incr', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    volumes:
      - redis-data:/data

  postgres:
    image: docker.io/pgvector/pgvector:pg16
    container_name: affine_postgres
    volumes:
      - ${DB_DATA_LOCATION:-./pgdata}:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${DB_USERNAME:-affine}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-affine}
      POSTGRES_DB: ${DB_DATABASE:-affine}
      POSTGRES_INITDB_ARGS: '--data-checksums'
      POSTGRES_HOST_AUTH_METHOD: trust
    healthcheck:
      test: ['CMD', 'pg_isready', '-U', '${DB_USERNAME:-affine}', '-d', '${DB_DATABASE:-affine}']
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  redis-data:
```

### Step 6: Create Environment File

Create `.docker/custom/.env`:

```bash
# Server Configuration
PORT=3010
AFFINE_SERVER_HOST=localhost
AFFINE_SERVER_HTTPS=false
# Or use: AFFINE_SERVER_EXTERNAL_URL=https://affine.yourdomain.com

# Data Persistence Locations (use absolute paths)
DB_DATA_LOCATION=/home/youruser/affine-data/postgres
UPLOAD_LOCATION=/home/youruser/affine-data/storage
CONFIG_LOCATION=/home/youruser/affine-data/config

# Database Credentials
DB_USERNAME=affine
DB_PASSWORD=your_secure_password_here
DB_DATABASE=affine

# Optional: Admin Email (first user becomes admin)
# AFFINE_ADMIN_EMAIL=admin@example.com
# AFFINE_ADMIN_PASSWORD=admin_password
```

### Step 7: Deploy with Podman

```bash
# Create data directories
mkdir -p /home/youruser/affine-data/{postgres,storage,config}

# Deploy using podman-compose
cd .docker/custom
podman-compose up -d

# Or using docker-compose with Podman socket
docker-compose up -d

# View logs
podman-compose logs -f

# Check status
podman-compose ps
```

### Step 8: Access AFFiNE

Open your browser and navigate to:
- **Local**: `http://localhost:3010`
- **Network**: `http://your-server-ip:3010`

The first user to register will automatically become the administrator.

---

## Podman-Specific Commands

### Using Podman Instead of Docker

```bash
# Build image
podman build -f .docker/custom/Dockerfile -t localhost/affine-custom:latest .

# Run containers
podman-compose up -d

# View logs
podman logs -f affine_server

# Stop containers
podman-compose down

# Stop and remove volumes
podman-compose down -v

# Restart a service
podman-compose restart affine

# Execute command in running container
podman exec -it affine_server sh
```

### Rootless Podman Setup

If running rootless Podman, ensure port 3010 is accessible:

```bash
# Allow binding to port 3010 (rootless)
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/podman-ports.conf
sudo sysctl --system

# Or use a higher port like 8010 and reverse proxy
```

### Using Podman Pod

Alternatively, you can create a Podman pod:

```bash
# Create pod
podman pod create --name affine-pod -p 3010:3010

# Run containers in pod
podman run -d --pod affine-pod --name affine_redis redis:latest
podman run -d --pod affine-pod --name affine_postgres \
  -e POSTGRES_PASSWORD=affine \
  -v ./pgdata:/var/lib/postgresql/data \
  pgvector/pgvector:pg16
podman run -d --pod affine-pod --name affine_server \
  -v ./storage:/root/.affine/storage \
  localhost/affine-custom:latest
```

---

## Updating Your Custom Build

When you make code changes:

```bash
# 1. Rebuild the project
yarn build

# 2. Rebuild the container image
podman build -f .docker/custom/Dockerfile -t localhost/affine-custom:latest .

# 3. Recreate containers
cd .docker/custom
podman-compose down
podman-compose up -d
```

---

## Backup and Restore

### Backup

```bash
# Backup database
podman exec affine_postgres pg_dump -U affine affine > affine_backup.sql

# Backup storage
tar -czf affine_storage_backup.tar.gz /home/youruser/affine-data/storage

# Or use volumes
podman volume export postgres-data --output postgres-backup.tar
```

### Restore

```bash
# Restore database
podman exec -i affine_postgres psql -U affine affine < affine_backup.sql

# Restore storage
tar -xzf affine_storage_backup.tar.gz -C /
```

---

## Troubleshooting

### Container won't start
```bash
# Check logs
podman logs affine_server

# Check health status
podman inspect affine_server | grep -A 10 Health
```

### Database connection errors
```bash
# Check PostgreSQL is running
podman exec affine_postgres pg_isready -U affine

# Test connection
podman exec affine_postgres psql -U affine -c "SELECT 1"
```

### Permission issues (rootless)
```bash
# Fix ownership of data directories
podman unshare chown -R 0:0 /home/youruser/affine-data/postgres
```

### Out of memory during build
```bash
# Increase Node.js memory
export NODE_OPTIONS="--max-old-space-size=8192"
yarn build
```

---

## Production Recommendations

1. **Use a reverse proxy** (Nginx/Caddy) with SSL:
   ```nginx
   server {
       listen 443 ssl http2;
       server_name affine.yourdomain.com;

       ssl_certificate /path/to/cert.pem;
       ssl_certificate_key /path/to/key.pem;

       location / {
           proxy_pass http://localhost:3010;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

2. **Enable PostgreSQL backups** with cron:
   ```bash
   0 2 * * * podman exec affine_postgres pg_dump -U affine affine > /backup/affine_$(date +\%Y\%m\%d).sql
   ```

3. **Set strong database password** in `.env`

4. **Monitor resource usage**:
   ```bash
   podman stats
   ```

5. **Set up systemd service** for auto-start:
   ```bash
   # Generate systemd unit files
   cd .docker/custom
   podman-compose --podman-run-args="--systemd=always" up
   podman generate systemd --new --files --name affine_server

   # Enable service
   cp container-affine_server.service ~/.config/systemd/user/
   systemctl --user enable --now container-affine_server.service
   ```

---

## Differences from Official Deployment

Your custom fork includes:

- ✅ **10GB frontend file size limit** (vs 2GB official)
- ✅ **1GB backend file size limit** (vs 100MB official)
- ✅ **5-minute upload timeout** (vs 15 seconds official)
- ✅ **999 member limit** (vs 3-10 official)
- ✅ **10TB storage quota** (vs 10-100GB official)
- ✅ **1-year history retention** (vs 7-30 days official)
- ✅ **No "Download App" or "Learn more" prompts**

**Remember**: These modifications are for personal use only, not for commercial deployment.

---

## References

- [AFFiNE Official Docs](https://docs.affine.pro)
- [Podman Documentation](https://docs.podman.io)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
