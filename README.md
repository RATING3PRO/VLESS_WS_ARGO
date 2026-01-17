# VLESS-WS-ARGO Docker Deployment

This project builds a Docker image that runs a **VLESS-WS** node using `sing-box` kernel, exposed via **Cloudflare Tunnel (Argo)**.

## Features

- **Kernel**: `sing-box` (High performance, modern architecture)
- **Protocol**: VLESS + WebSocket (Early Data supported)
- **Network**: Cloudflare Tunnel (No public IP required, works behind NAT)
- **Optimization**: Compatible with Cloudflare IP optimization ("优选IP")
- **Auto Config**: Automatically generates 5 optimized VLESS links in container logs.
- **Security**: WebSocket path is randomly generated based on UUID to prevent scanning.
- **Deployment**: Docker / Docker Compose / PaaS

## Prerequisites

1.  **Cloudflare Account**: You need a domain added to Cloudflare.
2.  **Cloudflare Tunnel**: Create a tunnel in the [Zero Trust Dashboard](https://one.dash.cloudflare.com/).
    *   Go to **Access** -> **Tunnels** -> **Create a Tunnel**.
    *   Name it and save.
    *   **Copy the Token** (You will see a command like `cloudflared.exe service install eyJh...` - the part starting with `eyJh...` is your token).
    *   **Configure Public Hostname**:
        *   In the tunnel settings, add a public hostname (e.g., `vless.yourdomain.com`).
        *   Service: `HTTP` -> `localhost:8080`.

## Quick Start (Docker Compose)

1.  Edit `docker-compose.yml` and fill in your variables:

    ```yaml
    version: '3'
    services:
      vless-argo:
        build: .
        container_name: vless-argo
        restart: always
        environment:
          - UUID= # Leave empty to auto-generate
          - ARGO_TOKEN=eyJhIjoi... # Your Cloudflare Tunnel Token
          - PUBLIC_HOSTNAME=vless.yourdomain.com # Set this to see share links in logs
    ```

2.  Build and run:

    ```bash
    docker-compose up -d --build
    ```

3.  Check logs for connection links:

    ```bash
    docker logs vless-argo
    ```
    
    You will see output like:
    ```text
    [INFO] VLESS Share Links (Import to v2rayN / sing-box / Clash)
    ---------------------------------------------------
    Server: cf.254301.xyz
    vless://uuid@cf.254301.xyz:443?encryption=none&security=tls&sni=vless.yourdomain.com&type=ws&host=vless.yourdomain.com&path=/uuid?ed=2048#cf.254301.xyz-Argo
    ...
    ```

## Environment Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `UUID` | VLESS User ID. If empty, a random one is generated on startup. | (Random) |
| `ARGO_TOKEN` | **Required**. Cloudflare Tunnel Token. | None |
| `PUBLIC_HOSTNAME` | Your Cloudflare Tunnel Domain (e.g. `vless.example.com`). Used to generate share links. | None |

**Note**: The WebSocket path is automatically set to `/{UUID}?ed=2048` to enhance security and enable Early Data support.

## GitHub Actions Workflow

This repository includes a GitHub Action `.github/workflows/docker-image.yml` that automatically builds and pushes the Docker image to GitHub Container Registry (ghcr.io) on push to `main` or when a tag starting with `v` is pushed.

### Usage
1. Fork this repository.
2. Enable GitHub Actions in your repository settings.
3. Push code to trigger build.
