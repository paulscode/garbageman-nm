# Garbageman Nodes Manager - Docker Images

This directory contains the unified Docker build configuration for Garbageman Nodes Manager, supporting multiple deployment wrappers through a single codebase.

## Architecture

### Unified Approach

All deployment targets (StartOS, Umbrel, Standalone) use the **same Dockerfile** with automatic wrapper detection at runtime. This eliminates code duplication and ensures consistency across all platforms.

**Key Components:**
- `Dockerfile` - Multi-stage production build
- `docker-entrypoint.sh` - Unified entrypoint with auto-detection
- `supervisord.*.conf` - Wrapper-specific process management configs
- `scripts/` - Helper utilities for password management and properties display

### Wrapper Detection

The entrypoint automatically detects the deployment environment using this logic:

1. **Explicit Override**: Check `WRAPPER_TYPE` environment variable
2. **StartOS Detection**: Check for `/root/start9/config.yaml` marker file
3. **Umbrel Detection**: Check for `APP_DATA_DIR` environment variable
4. **Default**: Fall back to standalone mode

This allows the same image to run correctly in any environment without manual configuration.

## Deployment Targets

### StartOS (Start9 Embassy OS)

**Characteristics:**
- Runs as root (required for StartOS volume access)
- Reads configuration from `/root/start9/config.yaml`
- Data directories under `/root/data`
- Packages as `.s9pk` file

**Build:**
```bash
docker buildx build \
  --platform linux/amd64 \
  --build-arg WRAPPER_TYPE=startos \
  --build-arg VERSION=0.2.1 \
  -t garbageman-nm:startos \
  .
```

**Configuration:**
- Uses `supervisord.startos.conf`
- Parses YAML config for ports, passwords, settings
- Exposes services via Tor hidden service

### Umbrel (Community App Store)

**Characteristics:**
- Runs as user 1000:1000 (Umbrel standard non-root)
- Uses `APP_DATA_DIR` for persistent data
- Integrates with Umbrel Tor proxy
- Auto-generates random WebUI password if not provided

**Build:**
```bash
docker buildx build \
  --platform linux/amd64 \
  --build-arg WRAPPER_TYPE=umbrel \
  --build-arg VERSION=0.2.1 \
  -t garbageman-nm:umbrel \
  .
```

**Configuration:**
- Uses `supervisord.umbrel.conf`
- Services run as user 1000
- Password saved to `/data/webui-password.txt`
- Properties script for Umbrel UI integration

**Helper Commands:**
```bash
# Show WebUI password
docker exec <container> show-password

# Display properties for Umbrel UI
docker exec <container> properties
```

### Standalone (Development/Self-Hosted)

**Characteristics:**
- Runs as root (development default)
- Flexible configuration via environment variables
- Data directories under `/data`
- No wrapper-specific dependencies

**Build:**
```bash
docker buildx build \
  --platform linux/amd64 \
  --build-arg WRAPPER_TYPE=standalone \
  --build-arg VERSION=0.2.1 \
  -t garbageman-nm:standalone \
  .
```

**Configuration:**
- Uses `supervisord.standalone.conf`
- Auto-generates password if not provided
- Suitable for Docker Compose or direct `docker run`

## Automated Publishing

GitHub Actions workflow (`.github/workflows/publish-docker.yml`) automatically builds and publishes images on version tags.

**Registries:**
- Docker Hub: `paulscode/garbageman-nm`
- GitHub Container Registry: `ghcr.io/paulscode/garbageman-nm`

**Tags:**
- `latest-umbrel`, `latest-startos`, `latest-standalone`
- `0.2.1-umbrel`, `0.2.1-startos`, `0.2.1-standalone`
- `0.2-umbrel`, `0-umbrel` (major.minor, major only)

**Trigger:**
```bash
# Create and push a version tag
git tag v0.2.1
git push origin v0.2.1

# GitHub Actions will automatically:
# 1. Build all three wrapper variants
# 2. Push to Docker Hub and GHCR
# 3. Tag with version and 'latest'
```

**Manual Trigger:**
```bash
# Via GitHub UI or gh CLI
gh workflow run publish-docker.yml \
  --ref main \
  -f tag=0.2.1 \
  -f publish=true
```

## File Structure

```
docker-images/
├── docker-entrypoint.sh          # Unified entrypoint (auto-detection)
├── supervisord.startos.conf      # StartOS process management
├── supervisord.umbrel.conf       # Umbrel process management
├── supervisord.standalone.conf   # Standalone process management
└── scripts/
    ├── show-password.sh          # Display WebUI password
    └── properties.sh             # Umbrel properties display
```

## Environment Variables

### Common (All Wrappers)

| Variable | Default | Description |
|----------|---------|-------------|
| `WRAPPER_TYPE` | auto-detect | Override wrapper detection (startos/umbrel/standalone) |
| `UI_PORT` | 5173 | Next.js UI server port |
| `API_PORT` | 8080 | Fastify API server port |
| `SUPERVISOR_PORT` | 9000 | Multi-daemon supervisor port |
| `LOG_LEVEL` | info | Logging verbosity (debug/info/warn/error) |
| `NODE_ENV` | production | Node.js environment |
| `TOR_PROXY_HOST` | 127.0.0.1 | Tor SOCKS5 proxy host |
| `TOR_PROXY_PORT` | 9050 | Tor SOCKS5 proxy port |

### Data Directories

| Variable | StartOS | Umbrel | Standalone |
|----------|---------|--------|------------|
| `DATA_DIR` | /root/data | /data/bitcoin | /data/bitcoin |
| `ENVFILES_DIR` | /root/envfiles | /data/envfiles | /data/envfiles |
| `ARTIFACTS_DIR` | /root/artifacts | /data/artifacts | /data/artifacts |

### Authentication

| Variable | Description |
|----------|-------------|
| `ADMIN_PASSWORD` | WebUI password (auto-generated if not set) |
| `WEBUI_PASSWORD` | Alias for ADMIN_PASSWORD |

## Development

### Local Build

```bash
# Build for testing
docker buildx build \
  --platform linux/amd64 \
  --build-arg WRAPPER_TYPE=standalone \
  --build-arg VERSION=dev \
  -t garbageman-nm:dev \
  -f ../Dockerfile \
  ..

# Run with auto-generated password
docker run -it --rm \
  -p 5173:5173 -p 8080:8080 -p 9000:9000 \
  -v gm-data:/data \
  garbageman-nm:dev

# Show password
docker exec <container> show-password
```

### Test Wrapper Detection

```bash
# Test StartOS detection
docker run -it --rm \
  -v $(pwd)/test-config.yaml:/root/start9/config.yaml \
  garbageman-nm:dev

# Test Umbrel detection
docker run -it --rm \
  -e APP_DATA_DIR=/umbrel/app-data \
  garbageman-nm:dev

# Test explicit override
docker run -it --rm \
  -e WRAPPER_TYPE=startos \
  garbageman-nm:dev
```

## Migration Guide

### For Wrapper Repositories

**StartOS (`garbageman-nm-startos`):**
1. Update `Makefile` to reference base Dockerfile:
   ```makefile
   docker buildx build \
     --build-arg WRAPPER_TYPE=startos \
     --build-arg VERSION=$(VERSION) \
     -f ../garbageman-nm/Dockerfile \
     ../garbageman-nm
   ```

2. Remove local `Dockerfile`, `docker_entrypoint.sh`, `supervisord.conf`
3. Keep wrapper-specific files: `manifest.yaml`, `Makefile`, `instructions.md`

**Umbrel (`garbageman-nm-umbrel`):**
1. Update `docker-compose.yml` to reference published image:
   ```yaml
   services:
     app:
       image: paulscode/garbageman-nm:${VERSION}-umbrel
   ```

2. Remove untracked `garbageman-nm/` build folder
3. Keep `app-store/` with `umbrel-app.yml` and `docker-compose.yml`
4. Update version in `exports.sh` and `umbrel-app.yml`

## Benefits

✅ **Single Source of Truth**: One Dockerfile, one entrypoint, one build process
✅ **Automatic Detection**: No manual configuration for wrapper type
✅ **Reduced Maintenance**: Changes in one place propagate to all wrappers
✅ **Version Control**: All configuration tracked in main repo
✅ **Automated Publishing**: GitHub Actions handles builds and registry updates
✅ **Consistency**: All wrappers use identical core code
✅ **Flexibility**: Explicit override available when needed

## Troubleshooting

### Wrong wrapper detected

**Solution:** Set `WRAPPER_TYPE` explicitly:
```bash
docker run -e WRAPPER_TYPE=umbrel ...
```

### Permission errors (Umbrel)

**Cause:** Volumes mounted with wrong ownership
**Solution:** Entrypoint fixes this automatically, but ensure container starts as root initially

### Password not found

**Cause:** Container still initializing or password provided via env
**Check:**
```bash
docker logs <container> | grep password
cat /data/webui-password.txt
```

### Service won't start

**Debug:**
```bash
# Check supervisord logs
docker exec <container> tail -f /var/log/supervisor/supervisord.log

# Check individual service logs
docker exec <container> supervisorctl status
docker exec <container> supervisorctl tail api
```

## References

- Main Repository: https://github.com/paulscode/garbageman-nm
- Docker Hub: https://hub.docker.com/r/paulscode/garbageman-nm
- GHCR: https://github.com/paulscode/garbageman-nm/pkgs/container/garbageman-nm
