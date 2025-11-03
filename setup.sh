#!/bin/bash
set -e

echo "Starting MeG Sepolia Node Setup (Geth + Prysm v6.x, checkpoint-sync clean)..."

# ====== user-config ======
FEE_RECIPIENT="0xYourFeeRecipientAddressHere"   # 建议填你自己的以太坊地址
CHECKPOINT_URL="https://checkpoint-sync.sepolia.ethpandaops.io"
PRYSM_IMAGE="gcr.io/offchainlabs/prysm/beacon-chain:v6.1.4"  # 可改为 :stable
GETH_IMAGE="ethereum/client-go:stable"
BASE_DIR="/root/ethereum"
EXEC_DIR="$BASE_DIR/execution"
CONS_DIR="$BASE_DIR/consensus"
JWT_FILE="$BASE_DIR/jwt.hex"
DC_FILE="$BASE_DIR/docker-compose.yml"
# ==========================

# Update & deps
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip

# Remove old docker variants if any
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  sudo apt-get remove -y "$pkg" || true
done

# Docker repo
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y && sudo apt upgrade -y

# Install Docker
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl restart docker

# Quick test
sudo docker run --rm hello-world || true

# Dirs
sudo mkdir -p "$EXEC_DIR" "$CONS_DIR"

# JWT
if [ ! -f "$JWT_FILE" ]; then
  openssl rand -hex 32 | sudo tee "$JWT_FILE" > /dev/null
fi

# Compose file
sudo tee "$DC_FILE" > /dev/null <<EOF
version: "3.8"
services:
  geth:
    image: ${GETH_IMAGE}
    container_name: geth
    network_mode: host
    restart: unless-stopped
    ports:
      - 30303:30303
      - 30303:30303/udp
      - 8545:8545
      - 8546:8546
      - 8551:8551
    volumes:
      - ${EXEC_DIR}:/data
      - ${JWT_FILE}:/jwt.hex
    command:
      - --sepolia
      - --http
      - --http.api=eth,net,web3
      - --http.addr=0.0.0.0
      - --authrpc.addr=0.0.0.0
      - --authrpc.vhosts=*
      - --authrpc.jwtsecret=/jwt.hex
      - --authrpc.port=8551
      - --syncmode=snap
      - --datadir=/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  prysm:
    image: ${PRYSM_IMAGE}
    container_name: prysm
    network_mode: host
    restart: unless-stopped
    depends_on:
      - geth
    volumes:
      - ${CONS_DIR}:/data
      - ${JWT_FILE}:/jwt.hex
    ports:
      - 4000:4000
      - 3500:3500
    command:
      - --sepolia
      - --accept-terms-of-use
      - --datadir=/data
      - --disable-monitoring
      - --rpc-host=0.0.0.0
      - --rpc-port=4000
      - --grpc-gateway-host=0.0.0.0
      - --grpc-gateway-port=3500
      - --grpc-gateway-corsdomain=*
      - --min-sync-peers=3
      - --execution-endpoint=http://127.0.0.1:8551
      - --jwt-secret=/jwt.hex
      - --checkpoint-sync-url=${CHECKPOINT_URL}
      - --genesis-beacon-api-url=${CHECKPOINT_URL}
      - --suggested-fee-recipient=${FEE_RECIPIENT}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

# Pull specific images (avoid old tags)
sudo docker pull "$GETH_IMAGE"
sudo docker pull "$PRYSM_IMAGE"

# Stop any existing stack
cd "$BASE_DIR"
sudo docker compose down || true

# *** CRITICAL: clean old consensus DB to avoid SSZ/version mismatches ***
if [ -d "${CONS_DIR}/beaconchaindata" ]; then
  echo "Cleaning old Prysm beaconchaindata (fresh checkpoint sync)..."
  sudo rm -rf "${CONS_DIR}/beaconchaindata"
fi

# Start
sudo docker compose up -d
echo "Docker containers started."

# UFW (adjust to your needs)
sudo ufw allow 22 || true
sudo ufw allow ssh || true
sudo ufw allow 30303/tcp || true
sudo ufw allow 30303/udp || true
# 默认仅本机访问 RPC；如需外放，请改成你的管理IP段
sudo ufw allow from 127.0.0.1 to any port 8545 proto tcp || true
sudo ufw allow from 127.0.0.1 to any port 3500 proto tcp || true
echo "If you need remote RPC, adjust UFW to allow specific source IPs."
sudo ufw enable || true
sudo ufw reload || true

echo "Setup complete! Your Sepolia node is running."
echo "Check logs with: sudo docker compose logs -f"

# Tail logs
sudo docker compose logs -f

