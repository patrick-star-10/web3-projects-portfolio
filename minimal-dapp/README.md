# Minimal DApp (Next.js + Wagmi + Viem + RainbowKit)

一个最小可运行的 Web3 前端示例，当前默认连接 **Foundry 本地链（Anvil，chainId: 31337）**。

## 项目框架（先看这部分）

### 1) 分层架构

- UI 组装层：`app/page.tsx`
  - 负责页面布局与模块拼装，不直接处理链上逻辑。
- 业务组件层：`components/*.tsx`
  - `ConnectSection`：钱包连接与网络状态展示
  - `ReadContract`：调用 `getValue()` 读取链上状态
  - `WriteContract`：调用 `setValue(uint256)` 发起交易并跟踪回执
  - `EventList`：历史事件拉取 + 实时事件订阅
- Web3 基础设施层：`components/Providers.tsx` + `config/wagmi.ts`
  - 统一注入 Wagmi / React Query / RainbowKit 上下文
  - 配置钱包连接器、链、RPC 传输
- 合约配置层：`config/contracts.ts`
  - 合约地址、链 ID、ABI 的单一真相源（Single Source of Truth）

### 2) 运行时数据流

1. 用户在 `ConnectSection` 中连接钱包。
2. `ReadContract` 通过 wagmi hook 读取 `getValue()`。
3. `WriteContract` 提交 `setValue()` 交易并等待确认。
4. 合约触发 `ValueChanged` 事件后：
   - `EventList` 实时监听到新日志并插入列表
   - 也可以手动刷新历史日志（`getLogs`）

### 3) 关键目录结构

```text
minimal-dapp/
├─ app/
│  ├─ layout.tsx          # 全局布局，挂载 Providers
│  ├─ page.tsx            # 页面入口，组装 4 个功能模块
│  └─ globals.css
├─ components/
│  ├─ Providers.tsx       # Wagmi + Query + RainbowKit + Toaster
│  ├─ ConnectSection.tsx  # 连接钱包 / 断开 / 网络检测
│  ├─ ReadContract.tsx    # 读取 getValue()
│  ├─ WriteContract.tsx   # 写入 setValue() 并等待回执
│  └─ EventList.tsx       # 历史 + 实时事件列表
├─ config/
│  ├─ wagmi.ts            # 钱包连接器、链、RPC 配置
│  └─ contracts.ts        # 合约地址、ABI、目标链配置
└─ contracts/
   ├─ src/ValueVault.sol  # 示例合约
   └─ out/...             # 编译产物
```

### 4) 配置关系（重点）

- `config/contracts.ts` 决定“连哪个合约、在哪条链上调用”。
- `config/wagmi.ts` 决定“钱包怎么连、RPC 走哪里”。
- 两者链配置应保持一致，否则会出现“网络不匹配”提示或调用失败。

## 功能说明

- 连接/断开钱包（RainbowKit）
- 读取合约：`getValue()`
- 写入合约：`setValue(uint256)`
- 事件列表：`ValueChanged(uint256 newValue)`
  - 初始拉取历史日志
  - 实时监听并追加新事件

## 技术栈

- Next.js (App Router) + TypeScript
- Tailwind CSS
- wagmi v2 + viem v2
- RainbowKit v2
- @tanstack/react-query
- sonner（Toast 提示）

## 环境要求

- Node.js: `>= 20`
- npm: `>= 10`

```bash
node -v
npm -v
```

## 快速开始

### 1) 安装依赖

```bash
npm install
```

### 2) 配置环境变量

```bash
cp .env.example .env.local
```

编辑 `.env.local`：

```env
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_walletconnect_project_id
NEXT_PUBLIC_LOCAL_RPC_URL=http://127.0.0.1:8545
```

说明：
- `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`：到 Reown/WalletConnect 控制台创建项目后获取。
- `NEXT_PUBLIC_LOCAL_RPC_URL`：本地链 RPC，默认是 Anvil 的 `8545` 端口。

### 3) 配置合约地址与 ABI

编辑 `config/contracts.ts`：

- `CONTRACT_ADDRESS`：目标合约地址
- `CONTRACT_CHAIN` / `CONTRACT_CHAIN_ID`：目标链
- `CONTRACT_ABI`：与链上部署合约保持一致

当前约定接口：
- `getValue() view returns (uint256)`
- `setValue(uint256)`
- `event ValueChanged(uint256 newValue)`

### 4) 启动开发环境

```bash
npm run dev
```

访问 `http://localhost:3000`。

## 合约测试（Foundry）

测试文件位置：

- `contracts/test/ValueVault.t.sol`

在项目根目录运行：

```bash
forge test --offline --root contracts
```

或先进入 `contracts` 再运行：

```bash
cd contracts
forge test --offline
```

说明：

- `--offline` 会禁用网络访问，适合本项目本地单元测试场景。
- 如果你本机 `forge test` 直接运行正常，也可以不加 `--offline`。

## 常见问题

### 1) 页面提示 `Please switch to ...`

原因：钱包当前链与 `config/contracts.ts` 中 `CONTRACT_CHAIN_ID` 不一致。

处理：
- 在钱包中切换到目标链
- 或修改 `config/contracts.ts` 与 `config/wagmi.ts` 的链配置保持一致

### 2) WalletConnect projectId 无效

处理：
- 检查 `.env.local` 中 `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`
- 修改后重启：

```bash
npm run dev
```

### 3) 读取或事件为空/报错

常见原因：
- 合约地址错误
- ABI 不匹配
- RPC 不可达

处理：
- 检查 `config/contracts.ts`
- 检查 `NEXT_PUBLIC_LOCAL_RPC_URL`
- 确认本地链已启动且合约已部署

## 生产构建

```bash
npm run build
npm run start
```
