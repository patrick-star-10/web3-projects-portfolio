#!/usr/bin/env bash
set -euo pipefail

RPC_URL="${RPC_URL:-http://127.0.0.1:8547}"
ANVIL_HOST="${ANVIL_HOST:-127.0.0.1}"
ANVIL_PORT="${ANVIL_PORT:-8547}"
BASE_URI="${BASE_URI:-https://meta.local/token/}"
TOKEN_NAME="${TOKEN_NAME:-Mini NFT Pro}"
TOKEN_SYMBOL="${TOKEN_SYMBOL:-MNFTP}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing command: $1" >&2
    exit 1
  fi
}

require_cmd anvil
require_cmd forge
require_cmd cast
require_cmd openssl
require_cmd curl

PRIVATE_KEY="0x$(openssl rand -hex 32)"
OWNER_ADDR="$(cast wallet address --private-key "$PRIVATE_KEY")"
RECEIVER_KEY="0x$(openssl rand -hex 32)"
RECEIVER_ADDR="$(cast wallet address --private-key "$RECEIVER_KEY")"

echo "Generated owner private key: $PRIVATE_KEY"
echo "Generated owner address:     $OWNER_ADDR"
echo "Generated receiver address:  $RECEIVER_ADDR"

ANVIL_LOG="/tmp/mininftpro-anvil.log"
anvil --host "$ANVIL_HOST" --port "$ANVIL_PORT" >"$ANVIL_LOG" 2>&1 &
ANVIL_PID=$!

cleanup() {
  if kill -0 "$ANVIL_PID" >/dev/null 2>&1; then
    kill "$ANVIL_PID" >/dev/null 2>&1 || true
    wait "$ANVIL_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

for _ in $(seq 1 30); do
  if curl -sS -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' >/dev/null 2>&1; then
    break
  fi
  sleep 0.3
done

if ! curl -sS -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' >/dev/null 2>&1; then
  echo "anvil failed to start, log: $ANVIL_LOG" >&2
  exit 1
fi

# Fund the generated owner address with 1000 ETH.
curl -sS -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"anvil_setBalance\",\"params\":[\"$OWNER_ADDR\",\"0x3635C9ADC5DEA00000\"],\"id\":1}" >/dev/null

PRIVATE_KEY="$PRIVATE_KEY" \
RECEIVER_ADDR="$RECEIVER_ADDR" \
TOKEN_NAME="$TOKEN_NAME" \
TOKEN_SYMBOL="$TOKEN_SYMBOL" \
BASE_URI="$BASE_URI" \
forge script script/LocalAnvilCheck.s.sol:LocalAnvilCheckScript \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -q

echo "Anvil local test script completed successfully."
