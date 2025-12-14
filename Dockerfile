# ==============================================================================
# Garbageman Nodes Manager - Production Dockerfile
# ==============================================================================
# Multi-stage build for minimal runtime image
# Target architecture: linux/amd64 (x86_64 only for now)
# Services: API (Fastify), UI (Next.js), Supervisor (Multi-daemon manager)
#
# Supports multiple deployment wrappers via WRAPPER_TYPE build arg:
# - standalone: Development/self-hosted (default)
# - startos:    Start9 Embassy OS package
# - umbrel:     Umbrel Community App Store
#
# Build args:
#   WRAPPER_TYPE: Deployment target (standalone|startos|umbrel)
#   VERSION:      Application version (for labels)

# ==============================================================================
# Stage 1: Build Dependencies Base
# ==============================================================================
FROM node:20-alpine AS deps-base

# Install build tools for native modules
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# ==============================================================================
# Stage 2: Install API Dependencies
# ==============================================================================
FROM deps-base AS api-deps

WORKDIR /build/api

# Copy package files
COPY webui/api/package*.json ./

# Install production dependencies
RUN npm ci --omit=dev && npm cache clean --force

# ==============================================================================
# Stage 3: Build API
# ==============================================================================
FROM deps-base AS api-builder

WORKDIR /build/api

# Copy package files and install ALL dependencies (including dev for TypeScript)
COPY webui/api/package*.json ./
RUN npm ci && npm cache clean --force

# Copy source files
COPY webui/api/tsconfig.json ./
COPY webui/api/src ./src
COPY webui/api/data ./data

# Build TypeScript
RUN npm run build

# ==============================================================================
# Stage 4: Install UI Dependencies
# ==============================================================================
FROM deps-base AS ui-deps

WORKDIR /build/ui

# Copy package files
COPY webui/ui/package*.json ./

# Install production dependencies
RUN npm ci --omit=dev && npm cache clean --force

# ==============================================================================
# Stage 5: Build UI (Next.js)
# ==============================================================================
FROM deps-base AS ui-builder

WORKDIR /build/ui

# Copy package files and install ALL dependencies (including dev)
COPY webui/ui/package*.json ./
RUN npm ci && npm cache clean --force

# Copy source files
COPY webui/ui/next.config.js ./
COPY webui/ui/tsconfig.json ./
COPY webui/ui/postcss.config.js ./
COPY webui/ui/tailwind.config.ts ./
COPY webui/ui/next-env.d.ts ./
COPY webui/ui/src ./src
COPY webui/ui/public ./public

# Build Next.js with standalone output
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
RUN npm run build

# ==============================================================================
# Stage 6: Install Supervisor Dependencies
# ==============================================================================
FROM deps-base AS supervisor-deps

WORKDIR /build/supervisor

# Copy package files
COPY multi-daemon/package*.json ./

# Install production dependencies
RUN npm ci --omit=dev && npm cache clean --force

# ==============================================================================
# Stage 7: Build Supervisor
# ==============================================================================
FROM deps-base AS supervisor-builder

WORKDIR /build/supervisor

# Copy package files and install ALL dependencies (including dev for TypeScript)
COPY multi-daemon/package*.json ./
RUN npm ci && npm cache clean --force

# Copy source files
COPY multi-daemon/tsconfig.json ./
COPY multi-daemon/*.ts ./
COPY multi-daemon/scripts ./scripts

# Build TypeScript
RUN npm run build

# ==============================================================================
# Stage 8: Runtime Image
# ==============================================================================
FROM node:20-alpine AS runtime

# Build args for wrapper detection
ARG WRAPPER_TYPE=standalone
ARG VERSION=unknown

# Labels for image metadata
LABEL org.opencontainers.image.title="Garbageman Nodes Manager"
LABEL org.opencontainers.image.description="Multi-daemon Bitcoin Core node manager"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.source="https://github.com/paulscode/garbageman-nm"
LABEL org.opencontainers.image.wrapper="${WRAPPER_TYPE}"

# Install runtime dependencies only
RUN apk add --no-cache \
    curl \
    unzip \
    xz \
    tini \
    supervisor \
    zeromq \
    su-exec \
    libevent \
    libevent-dev \
    tor \
    && rm -rf /var/cache/apk/*

# Create app directory structure
WORKDIR /app

# Copy API build artifacts
COPY --from=api-builder /build/api/dist ./api/dist
COPY --from=api-builder /build/api/data ./api/data
COPY --from=api-deps /build/api/node_modules ./api/node_modules
COPY --from=api-builder /build/api/package.json ./api/

# Copy UI build artifacts (Next.js standalone)
COPY --from=ui-builder /build/ui/.next/standalone ./ui/
COPY --from=ui-builder /build/ui/.next/static ./ui/.next/static
COPY --from=ui-builder /build/ui/public ./ui/public
COPY --from=ui-builder /build/ui/package.json ./ui/

# Copy Supervisor build artifacts
COPY --from=supervisor-builder /build/supervisor/dist ./supervisor/dist
COPY --from=supervisor-builder /build/supervisor/scripts ./supervisor/scripts
COPY --from=supervisor-deps /build/supervisor/node_modules ./supervisor/node_modules
COPY --from=supervisor-builder /build/supervisor/package.json ./supervisor/

# Copy unified entrypoint script
COPY docker-images/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Copy wrapper-specific supervisord configurations
COPY docker-images/supervisord.startos.conf /etc/supervisord.startos.conf
COPY docker-images/supervisord.umbrel.conf /etc/supervisord.umbrel.conf
COPY docker-images/supervisord.standalone.conf /etc/supervisord.standalone.conf

# Copy helper scripts (for Umbrel properties display and password retrieval)
COPY docker-images/scripts/show-password.sh /usr/local/bin/show-password
COPY docker-images/scripts/properties.sh /usr/local/bin/properties
RUN chmod +x /usr/local/bin/show-password /usr/local/bin/properties

# Create data directory structure (will be mounted as volumes)
RUN mkdir -p /data/bitcoin /data/envfiles /data/artifacts /data/tor

# Wrapper-specific user setup
# - StartOS: Runs as root (required for StartOS volume management)
# - Umbrel: Runs as 1000:1000 (Umbrel standard non-root user)
# - Standalone: Runs as root (development/self-hosted default)
#
# Note: The entrypoint script handles permission fixes for mounted volumes
# User is specified by docker-compose.yml or runtime, not in Dockerfile
RUN if [ "$WRAPPER_TYPE" = "umbrel" ]; then \
        chown -R 1000:1000 /data /app; \
    fi

# Health check on UI port
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5173/ || exit 1

# Expose ports (for documentation, actual mapping controlled by deployment)
EXPOSE 5173 8080 9000

# Use tini as init system for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]

# Start via unified entrypoint script (will auto-detect wrapper)
CMD ["docker-entrypoint.sh"]
