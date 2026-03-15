#!/usr/bin/env bash
set -euo pipefail

# =========================
# Anvil 默认账号（你贴出来的）
# =========================
ADDR0="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ADDR1="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
ADDR2="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

PK0="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
PK1="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
PK2="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

MNEMONIC="test test test test test test test test test test test junk"
RPC_URL="http://127.0.0.1:8545"
CHAIN_ID="31337"

# =========================
# 目录与文件
# =========================
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$ROOT_DIR/src"
TEST_DIR="$ROOT_DIR/test"

INPUT_SOL="$ROOT_DIR/MiniTokenPro.sol"
INPUT_TEST="$ROOT_DIR/MiniTokenPro.t.sol"

TARGET_SOL="$SRC_DIR/MiniTokenPro.sol"
TARGET_TEST="$TEST_DIR/MiniTokenPro.t.sol"

# =========================
# 依赖检查
# =========================
need_cmd () {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ 缺少命令：$1（请先安装 Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup）"
    exit 1
  fi
}
need_cmd forge
need_cmd cast
need_cmd anvil

echo "==> Project root: $ROOT_DIR"

# =========================
# 初始化 Foundry 项目（如无）
# =========================
if [ ! -f "$ROOT_DIR/foundry.toml" ]; then
  echo "==> 未发现 foundry.toml，初始化 Foundry 项目..."
  (cd "$ROOT_DIR" && forge init --no-commit >/dev/null)
fi

# =========================
# 检查输入文件
# =========================
if [ ! -f "$INPUT_SOL" ]; then
  echo "❌ 找不到 $INPUT_SOL（请把 MiniTokenPro.sol 放到脚本同级目录）"
  exit 1
fi
if [ ! -f "$INPUT_TEST" ]; then
  echo "❌ 找不到 $INPUT_TEST（请把 MiniTokenPro.t.sol 放到脚本同级目录）"
  exit 1
fi

# =========================
# 放到标准目录结构（保证 import ../src/... 能工作）
# =========================
mkdir -p "$SRC_DIR" "$TEST_DIR"
cp -f "$INPUT_SOL" "$TARGET_SOL"
cp -f "$INPUT_TEST" "$TARGET_TEST"

# 尝试自动修正测试文件的 import 路径为 ../src/MiniTokenPro.sol
if ! grep -q 'import "\.\./src/MiniTokenPro\.sol";' "$TARGET_TEST"; then
  echo "==> 修正测试文件 import 路径为 ../src/MiniTokenPro.sol"
  if sed --version >/dev/null 2>&1; then
    sed -i 's|^import .*MiniTokenPro\.sol.*;|import "../src/MiniTokenPro.sol";|g' "$TARGET_TEST"
  else
    sed -i '' 's|^import .*MiniTokenPro\.sol.*;|import "../src/MiniTokenPro.sol";|g' "$TARGET_TEST"
  fi
fi

# =========================
# 先跑单元测试
# =========================
echo "==> forge clean && forge build && forge test -vvv"
(cd "$ROOT_DIR" && forge clean >/dev/null)
(cd "$ROOT_DIR" && forge build >/dev/null)
(cd "$ROOT_DIR" && forge test -vvv)

# =========================
# 启动 anvil（保证私钥/地址固定）
# =========================
cleanup() {
  if [ -n "${ANVIL_PID:-}" ] && kill -0 "$ANVIL_PID" >/dev/null 2>&1; then
    echo "==> stopping anvil (pid=$ANVIL_PID)"
    kill "$ANVIL_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# 如果本地 8545 已经有节点在跑，就不重复启动；否则启动一个带默认 mnemonic 的 anvil
if cast chain-id --rpc-url "$RPC_URL" >/dev/null 2>&1; then
  echo "==> RPC already running at $RPC_URL (skip starting anvil)"
else
  echo "==> starting anvil at $RPC_URL (chain_id=$CHAIN_ID)"
  anvil --mnemonic "$MNEMONIC" --chain-id "$CHAIN_ID" --port 8545 >/dev/null 2>&1 &
  ANVIL_PID=$!
  # 等待节点起来
  for i in {1..40}; do
    if cast chain-id --rpc-url "$RPC_URL" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
  cast chain-id --rpc-url "$RPC_URL" >/dev/null 2>&1 || { echo "❌ anvil 启动失败"; exit 1; }
fi

echo "==> chain-id: $(cast chain-id --rpc-url "$RPC_URL")"
echo "==> deployer: $ADDR0"

# =========================
# 部署合约（constructor: name, symbol, decimals, owner）
# =========================
TOKEN_NAME="MiniTokenPro"
TOKEN_SYMBOL="MTP"
TOKEN_DECIMALS="18"

echo "==> deploying MiniTokenPro..."
DEPLOY_OUT="$(cd "$ROOT_DIR" && forge create src/MiniTokenPro.sol:MiniTokenPro \
  --rpc-url "$RPC_URL" \
  --private-key "$PK0" \
  --constructor-args "$TOKEN_NAME" "$TOKEN_SYMBOL" "$TOKEN_DECIMALS" "$ADDR0 \
  --broadcast 2>&1)"

echo "$DEPLOY_OUT"

TOKEN_ADDR="$(echo "$DEPLOY_OUT" | grep -Eo 'Deployed to: 0x[a-fA-F0-9]{40}' | awk '{print $3}' | tail -n 1)"
if [ -z "$TOKEN_ADDR" ]; then
  echo "❌ 无法从 forge create 输出中解析合约地址"
  exit 1
fi
echo "✅ Token deployed at: $TOKEN_ADDR"

# =========================
# 冒烟测试：mint/transfer/approve/transferFrom
# =========================
# 1) owner mint 给自己 1_000 tokens (按 18 位)
MINT_AMOUNT="1000000000000000000000"   # 1000e18
echo "==> mint to owner: 1000 tokens"
cast send "$TOKEN_ADDR" "mint(address,uint256)" "$ADDR0" "$MINT_AMOUNT" \
  --private-key "$PK0" --rpc-url "$RPC_URL" >/dev/null

# 2) owner transfer 给 addr1 100 tokens
TRANSFER_AMOUNT="100000000000000000000" # 100e18
echo "==> transfer to addr1: 100 tokens"
cast send "$TOKEN_ADDR" "transfer(address,uint256)" "$ADDR1" "$TRANSFER_AMOUNT" \
  --private-key "$PK0" --rpc-url "$RPC_URL" >/dev/null

# 3) owner approve addr1 可花 50 tokens
APPROVE_AMOUNT="50000000000000000000"   # 50e18
echo "==> approve addr1 to spend 50 tokens from owner"
cast send "$TOKEN_ADDR" "approve(address,uint256)" "$ADDR1" "$APPROVE_AMOUNT" \
  --private-key "$PK0" --rpc-url "$RPC_URL" >/dev/null

# 4) addr1 使用 transferFrom 从 owner 转 20 tokens 给 addr2
TF_AMOUNT="20000000000000000000"        # 20e18
echo "==> addr1 transferFrom(owner -> addr2): 20 tokens"
cast send "$TOKEN_ADDR" "transferFrom(address,address,uint256)" "$ADDR0" "$ADDR2" "$TF_AMOUNT" \
  --private-key "$PK1" --rpc-url "$RPC_URL" >/dev/null

# 5) 打印余额
bal() {
  cast call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$1" --rpc-url "$RPC_URL"
}
echo "==> balances (raw uint256):"
echo "   owner: $(bal "$ADDR0")"
echo "   addr1: $(bal "$ADDR1")"
echo "   addr2: $(bal "$ADDR2")"

echo "✅ smoke test done."