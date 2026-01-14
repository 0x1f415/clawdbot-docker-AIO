# Clawdbot Gateway - Docker (Unraid)

An all-in-one Docker image for running a Clawdbot gateway. This is designed for Unraid hosts that don't support docker-compose, based on the [official Clawdbot Docker setup](https://docs.clawd.bot/install/docker).

[![Build and Push Docker Image](https://github.com/YOUR_USERNAME/clawdbot-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/YOUR_USERNAME/clawdbot-docker/actions/workflows/docker-build.yml)

## Overview

Clawdbot is an AI agent platform that connects Claude (and other LLMs) to messaging platforms like WhatsApp, Telegram, Discord, and more. This Docker image provides a containerized gateway that you can run on Unraid or any Docker host.

## Prerequisites

- Docker installed
- Anthropic API key (get one at https://console.anthropic.com/)

## Quick Start

### Option 1: Use Pre-built Image from GHCR (Recommended)

Pull the latest pre-built image from GitHub Container Registry:

```bash
docker pull ghcr.io/YOUR_USERNAME/clawdbot-docker:latest
```

Then skip to step 4 below and use `ghcr.io/YOUR_USERNAME/clawdbot-docker:latest` as the image name.

### Option 2: Build Locally

### 1. Clone Clawdbot Repository

First, clone the official Clawdbot repository:

```bash
git clone https://github.com/clawdbot/clawdbot.git
cd clawdbot
```

### 2. Copy This Dockerfile

Copy this `Dockerfile` into the clawdbot repository root.

### 3. Build the Image

Build with optional apt packages for plugins:

```bash
docker build \
  --build-arg CLAWDBOT_DOCKER_APT_PACKAGES="ffmpeg build-essential" \
  -t clawdbot:latest \
  .
```

Or build without extra packages:

```bash
docker build -t clawdbot:latest .
```

### 4. Create Configuration Directory

```bash
mkdir -p ~/.clawdbot
```

### 5. Run Initial Setup (Onboarding)

Run the onboarding wizard to create your initial configuration:

```bash
docker run -it --rm \
  -v ~/.clawdbot:/root/.clawdbot \
  -v ~/clawd:/root/clawd \
  clawdbot:latest \
  node dist/index.js onboard
```

This will guide you through:
- Creating your first agent
- Setting up your Anthropic API key
- Configuring providers and models

### 6. Run the Gateway

```bash
docker run -d \
  --name clawdbot-gateway \
  -p 18789:18789 \
  -p 18790:18790 \
  -v ~/.clawdbot:/root/.clawdbot \
  -v ~/clawd:/root/clawd \
  --restart unless-stopped \
  clawdbot:latest
```

The gateway will now be running with:
- **Control UI / Dashboard**: http://localhost:18789
- **WebChat** (optional): http://localhost:18790

## Unraid Setup

### Container Configuration

Add a new container in Unraid with these settings:

**Basic Settings:**
- **Name**: `clawdbot-gateway`
- **Repository**: `ghcr.io/YOUR_USERNAME/clawdbot-docker:latest` (or `clawdbot:latest` if built locally)
- **Network Type**: `Bridge`

**Port Mappings:**
- Container Port `18789` → Host Port `18789` (TCP) - Control UI
- Container Port `18790` → Host Port `18790` (TCP) - WebChat

**Volume Mappings:**
- Container Path: `/root/.clawdbot` → Host Path: `/mnt/user/appdata/clawdbot/config`
- Container Path: `/root/clawd` → Host Path: `/mnt/user/appdata/clawdbot/workspace`

**Advanced:**
- Extra Parameters: `--restart unless-stopped`

### First Run on Unraid

Before starting the container, run the onboarding wizard:

```bash
docker run -it --rm \
  -v /mnt/user/appdata/clawdbot/config:/root/.clawdbot \
  -v /mnt/user/appdata/clawdbot/workspace:/root/clawd \
  ghcr.io/YOUR_USERNAME/clawdbot-docker:latest \
  node dist/index.js onboard
```

Then start the container normally through the Unraid UI.

## Configuration

### Directory Structure

- `~/.clawdbot/` - Configuration files, agent configs, sessions
- `~/clawd/` - Agent workspace for file operations

### Adding Channels

To add messaging channels (WhatsApp, Telegram, Discord), use the CLI:

**WhatsApp (QR Code):**
```bash
docker exec -it clawdbot-gateway node dist/index.js channels login
```

**Telegram (Bot Token):**
```bash
docker exec -it clawdbot-gateway node dist/index.js channels add --channel telegram --token "YOUR_BOT_TOKEN"
```

**Discord (Bot Token):**
```bash
docker exec -it clawdbot-gateway node dist/index.js channels add --channel discord --token "YOUR_BOT_TOKEN"
```

See [Clawdbot Channels Documentation](https://docs.clawd.bot/channels) for more details.

### Environment Variables

You can pass additional configuration via environment variables:

```bash
docker run -d \
  --name clawdbot-gateway \
  -p 18789:18789 \
  -p 18790:18790 \
  -e NODE_ENV=production \
  -e ANTHROPIC_API_KEY=your-api-key \
  -v ~/.clawdbot:/root/.clawdbot \
  -v ~/clawd:/root/clawd \
  --restart unless-stopped \
  clawdbot:latest
```

## Installing Additional Packages

The Dockerfile supports installing apt packages during build for plugin compatibility:

```bash
docker build \
  --build-arg CLAWDBOT_DOCKER_APT_PACKAGES="ffmpeg imagemagick git curl jq" \
  -t clawdbot:latest \
  .
```

Common packages you might need:
- `ffmpeg` - Audio/video processing
- `imagemagick` - Image manipulation
- `git` - Git operations
- `build-essential` - Compiling native modules
- `python3` - Python scripts

## Health Check

Check if the gateway is healthy:

```bash
docker exec clawdbot-gateway node dist/index.js health
```

## Updating

### Using Pre-built Images (GHCR)

If you're using the pre-built image from GHCR, simply pull the latest version:

```bash
docker pull ghcr.io/YOUR_USERNAME/clawdbot-docker:latest
docker stop clawdbot-gateway
docker rm clawdbot-gateway
```

Then start a new container with the same volume mounts. Images are automatically built and pushed on every commit to the main branch.

### Building Locally

To update when building locally:

1. Pull the latest changes:
```bash
cd clawdbot
git pull origin main
```

2. Rebuild the image:
```bash
docker build -t clawdbot:latest .
```

3. Stop and remove the old container:
```bash
docker stop clawdbot-gateway
docker rm clawdbot-gateway
```

4. Start a new container with the same volume mounts

## Automated Builds

This repository uses GitHub Actions to automatically build and push Docker images to GitHub Container Registry (GHCR) on:
- Every push to the `main` branch (tagged as `latest`)
- Every version tag (e.g., `v1.0.0`)
- Pull requests (for testing)

Images are available at: `ghcr.io/YOUR_USERNAME/clawdbot-docker`

Available tags:
- `latest` - Latest build from main branch
- `main` - Same as latest
- `v1.0.0` - Specific version tags
- `sha-abc1234` - Specific commit SHA

To use a specific version:
```bash
docker pull ghcr.io/YOUR_USERNAME/clawdbot-docker:v1.0.0
```

## Troubleshooting

### View Logs
```bash
docker logs -f clawdbot-gateway
```

### Access Container Shell
```bash
docker exec -it clawdbot-gateway /bin/bash
```

### Configuration Issues
Check your configuration files in `~/.clawdbot/config.js` or `~/.clawdbot/config.json5`

### Port Conflicts
If ports 18789 or 18790 are already in use, change the host port:
```bash
-p 8080:18789  # Use port 8080 instead
```

## Documentation

- [Official Clawdbot Docs](https://docs.clawd.bot/)
- [Docker Installation Guide](https://docs.clawd.bot/install/docker)
- [Gateway Configuration](https://docs.clawd.bot/gateway/configuration)
- [Channels Setup](https://docs.clawd.bot/channels)

## License

Clawdbot is open source. Check the [official repository](https://github.com/clawdbot/clawdbot) for license details.
