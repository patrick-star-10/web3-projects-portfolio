#!/usr/bin/env bash
set -euo pipefail

# ============= 基本配置 =============
RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
CHAIN_ID="${CHAIN_ID:-31337}"

# 你给的 anvil 默认账户(0) 私钥
PK0="${PK0:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"

# 你给的 anvil 默认账户(1) 私钥（用来模拟另一个用户）
PK1="${PK1:-0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}"

# 合约路径 & 合约名（确保你的工程里确实是这个路径/名字）
CONTRACT_PATH="${CONTRACT_PATH:-src/MiniTokenPro.sol:MiniTokenPro}"

# 部署参数（constructor(string _name, string _symbol, uint8 _decimals, address _owner)）
TOKEN_NAME="${TOKEN_NAME:-MiniTokenPro}"
TOKEN_SYMBOL="${TOKEN_SYMBOL:-MTP}"
TOKEN_DECIMALS="${TOKEN_DECIMALS:-18}"

# ============= 计算地址 =============
DEPLOYER="$(cast wallet address --private-key "$PK0")"
USER1="$(cast wallet address --private-key "$PK1")"

echo "RPC_URL     : $RPC_URL"
echo "CHAIN_ID    : $CHAIN_ID"
echo "DEPLOYER(0) : $DEPLOYER"
echo "USER1(1)    : $USER1"
echo

# ============= 0) 编译 =============
echo "==> [0] forge build"
forge build -q
echo

# ============= 1) 部署 =============
echo "==> [1] Deploy MiniTokenPro"
# 使用 forge create（最常用、最稳）
DEPLOY_OUT="$(forge create \
  --rpc-url "$RPC_URL" \
  --private-key "$PK0" \
  "$CONTRACT_PATH" \
  --constructor-args "$TOKEN_NAME" "$TOKEN_SYMBOL" "$TOKEN_DECIMALS" "$DEPLOYER")"

echo "$DEPLOY_OUT"
TOKEN_ADDR="$(echo "$DEPLOY_OUT" | awk '/Deployed to:/ {print $3}')"
if [[ -z "${TOKEN_ADDR:-}" ]]; then
  echo "ERROR: parse deployed address failed"
  exit 1
fi

echo "TOKEN_ADDR  : $TOKEN_ADDR"
echo

# ============= 2) 读基础信息 =============
echo "==> [2] Read token meta"
echo -n "name      : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "name()(string)"
echo -n "symbol    : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "symbol()(string)"
echo -n "decimals  : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "decimals()(uint8)"
echo -n "owner     : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "owner()(address)"
echo -n "totalSupply: "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "totalSupply()(uint256)"
echo

# ============= 3) mint 给 deployer + user1 =============
# mint 1000 * 10^decimals 给 deployer
MINT0_WEI="$(cast --to-wei 1000)"
MINT1_WEI="$(cast --to-wei 200)"
echo "==> [3] mint"
cast send --rpc-url "$RPC_URL" --private-key "$PK0" "$TOKEN_ADDR" "mint(address,uint256)" "$DEPLOYER" "$MINT0_WEI" > /dev/null
cast send --rpc-url "$RPC_URL" --private-key "$PK0" "$TOKEN_ADDR" "mint(address,uint256)" "$USER1"   "$MINT1_WEI" > /dev/null

echo -n "balance deployer: "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$DEPLOYER"
echo -n "balance user1   : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$USER1"
echo -n "totalSupply     : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "totalSupply()(uint256)"
echo

# ============= 4) transfer: deployer -> user1 10 tokens =============
XFER_WEI="$(cast --to-wei 10)"
echo "==> [4] transfer deployer -> user1 (10)"
cast send --rpc-url "$RPC_URL" --private-key "$PK0" "$TOKEN_ADDR" "transfer(address,uint256)" "$USER1" "$XFER_WEI" > /dev/null
echo -n "balance deployer: "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$DEPLOYER"
echo -n "balance user1   : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$USER1"
echo

# ============= 5) approve + transferFrom: user1 授权 deployer 30 tokens，然后 deployer 拉走 5 tokens =============
APPROVE_WEI="$(cast --to-wei 30)"
PULL_WEI="$(cast --to-wei 5)"
echo "==> [5] approve user1 -> deployer (30), then transferFrom(user1->deployer, 5)"
cast send --rpc-url "$RPC_URL" --private-key "$PK1" "$TOKEN_ADDR" "approve(address,uint256)" "$DEPLOYER" "$APPROVE_WEI" > /dev/null

echo -n "allowance(user1, deployer): "
cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "allowance(address,address)(uint256)" "$USER1" "$DEPLOYER"

cast send --rpc-url "$RPC_URL" --private-key "$PK0" "$TOKEN_ADDR" "transferFrom(address,address,uint256)" "$USER1" "$DEPLOYER" "$PULL_WEI" > /dev/null

echo -n "allowance(user1, deployer): "
cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "allowance(address,address)(uint256)" "$USER1" "$DEPLOYER"
echo -n "balance deployer: "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$DEPLOYER"
echo -n "balance user1   : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$USER1"
echo

# ============= 6) burn: deployer 自己烧 3 tokens =============
BURN_WEI="$(cast --to-wei 3)"
echo "==> [6] burn deployer (3)"
cast send --rpc-url "$RPC_URL" --private-key "$PK0" "$TOKEN_ADDR" "burn(uint256)" "$BURN_WEI" > /dev/null
echo -n "balance deployer: "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$DEPLOYER"
echo -n "totalSupply     : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "totalSupply()(uint256)"
echo

# ============= 7) burnFrom: user1 再授权 deployer 7 tokens，然后 deployer burnFrom(user1, 2) =============
APPROVE2_WEI="$(cast --to-wei 7)"
BURNFROM_WEI="$(cast --to-wei 2)"
echo "==> [7] burnFrom: user1 approve deployer (7), then deployer burnFrom(user1, 2)"
cast send --rpc-url "$RPC_URL" --private-key "$PK1" "$TOKEN_ADDR" "approve(address,uint256)" "$DEPLOYER" "$APPROVE2_WEI" > /dev/null
cast send --rpc-url "$RPC_URL" --private-key "$PK0" "$TOKEN_ADDR" "burnFrom(address,uint256)" "$USER1" "$BURNFROM_WEI" > /dev/null

echo -n "balance user1   : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$USER1"
echo -n "totalSupply     : "; cast call --rpc-url "$RPC_URL" "$TOKEN_ADDR" "totalSupply()(uint256)"
echo

echo "✅ Done. TOKEN_ADDR=$TOKEN_ADDR"