# Docker Deployment for Prysel C7 Miner & CDCI Node

This Docker Compose setup deploys both:
1. **`c7-node`**: CentralDataBase CDCI full node daemon with mining RPC enabled (`generatetoaddress`).
2. **`c7-minerd`**: The miner controller and block checker connected to `c7-node` and monitoring `https://blocks.prysel.com/`.

## Prerequisites

- Docker and Docker Compose installed and running.

## Quick Start

1. Configure environment (a default `.env` is already created from `config.example.env`):

```bash
cp config.example.env .env
```

2. Build and start both node and miner:

```bash
docker compose -f docker/docker-compose.yml up -d --build
```

3. Check logs of the miner and block checker:

```bash
docker compose -f docker/docker-compose.yml logs -f c7-minerd
```

4. Check blocks and compare with https://blocks.prysel.com/:

```bash
# On host:
./scripts/check-blocks.sh

# Inside Docker:
docker compose -f docker/docker-compose.yml exec c7-minerd check-blocks
```

5. Stop containers:

```bash
docker compose -f docker/docker-compose.yml down
```

## Useful Commands

- **Node status**:
  ```bash
  docker compose -f docker/docker-compose.yml exec c7-node centraldatabase-cli -rpcuser=c7miner -rpcpassword=change-me getblockchaininfo
  ```

- **Mining info**:
  ```bash
  docker compose -f docker/docker-compose.yml exec c7-node centraldatabase-cli -rpcuser=c7miner -rpcpassword=change-me getmininginfo
  ```
