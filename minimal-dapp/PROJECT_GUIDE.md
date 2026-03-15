# Minimal DApp 项目详解（学习版）

这份文档用于从学习角度解释你当前项目中每一个关键文件的作用、内容和它在运行流程中的位置。

## 1. 项目总体架构

这是一个基于 **Next.js App Router + TypeScript + Tailwind** 的前端 DApp，核心能力：

- 钱包连接（RainbowKit）
- 合约读取（`getValue()`）
- 合约写入（`setValue(uint256)`）
- 事件历史 + 实时监听（`ValueChanged`）

技术栈：

- `wagmi v2`：React hooks 层（连接钱包、读写合约、监听事件）
- `viem v2`：底层 EVM 客户端和类型能力
- `@tanstack/react-query`：wagmi 内部依赖的查询缓存层
- `RainbowKit`：钱包连接 UI
- `sonner`：提示消息（toast）

---

## 2. 目录结构（你当前项目）

```txt
minimal-dapp/
├─ app/
│  ├─ globals.css
│  ├─ layout.tsx
│  └─ page.tsx
├─ components/
│  ├─ Providers.tsx
│  ├─ ConnectSection.tsx
│  ├─ ReadContract.tsx
│  ├─ WriteContract.tsx
│  └─ EventList.tsx
├─ config/
│  ├─ wagmi.ts
│  └─ contracts.ts
├─ .env.example
├─ README.md
├─ PROJECT_GUIDE.md
├─ next-env.d.ts
├─ next.config.ts
├─ package.json
├─ package-lock.json
├─ postcss.config.js
├─ tailwind.config.ts
├─ tsconfig.json
├─ .next/            (构建输出，自动生成)
└─ node_modules/     (依赖目录，自动生成)
```

---

## 3. 运行流程（先理解）

1. 浏览器请求页面 `/`
2. Next.js 进入 `app/layout.tsx`（全局布局）
3. `layout` 包裹 `Providers`，注入 wagmi / query / rainbowkit 上下文
4. 渲染 `app/page.tsx`
5. `page.tsx` 组合四个功能组件：连接、读取、写入、事件列表
6. 各组件通过 `wagmi` hooks 与 Sepolia 链交互

---

## 4. 文件逐个解释

## 4.1 `app/` 目录

### `app/layout.tsx`

**作用**：全局布局入口（App Router 必备），对所有页面生效。

**你这里做了什么**：

- 引入全局样式 `globals.css`
- 定义页面元信息 `metadata`（title/description）
- 用 `<Providers>` 包裹整个应用，提供 Web3 所需上下文

**重点**：

- `layout.tsx` 是 Server Component（默认），不写业务 hooks
- 所有 wagmi/rainbowkit hooks 都放在 client 组件中

---

### `app/page.tsx`

**作用**：主页 UI 组装层。

**你这里做了什么**：

- Header（标题与描述）
- `ConnectSection`（钱包连接区）
- `ReadContract + WriteContract`（响应式两列/移动端单列）
- `EventList`（事件历史+实时）

**重点**：

- 这个文件本身是 Server Component，只负责布局拼装
- 真正交互在子组件中完成

---

### `app/globals.css`

**作用**：全局 CSS 样式入口。

**你这里做了什么**：

- 注入 Tailwind 三层指令（base/components/utilities）
- 定义全局背景、字体、颜色变量
- 定义一组可复用 UI 样式类（例如 `ui-card`, `ui-btn`, `ui-input`）

**学习点**：

- 把视觉规范沉淀成可复用类，组件里只组合 class，不重复写样式

---

## 4.2 `components/` 目录

### `components/Providers.tsx`

**作用**：全局 Web3 Provider 组合器（唯一入口）。

**内容结构**：

- `WagmiProvider config={wagmiConfig}`
- `QueryClientProvider client={queryClient}`
- `RainbowKitProvider`
- `Toaster`（sonner）

**为什么必须是 Client Component**：

- 这些 provider 依赖浏览器环境和 React hooks
- 文件顶部有 `'use client'`

**这是整个 DApp 的基础设施层。**

---

### `components/ConnectSection.tsx`

**作用**：钱包连接与链状态显示。

**核心逻辑**：

- 使用 RainbowKit `ConnectButton`
- 使用 `useAccount()` 获取 `address/chain/status`
- 使用 `useDisconnect()` 断开钱包
- 地址缩写展示（例如 `0x1234...abcd`）
- 当前链不是 Sepolia 时显示警告

**学习点**：

- UI 与链状态联动（连接状态、链 id、地址）

---

### `components/ReadContract.tsx`

**作用**：读取合约 `getValue()`。

**核心逻辑**：

- `useReadContract` 传入：`address`、`abi`、`functionName: 'getValue'`、`chainId`
- 状态分支：`isLoading` / `isError` / success
- 提供 `refetch()` 手动刷新

**学习点**：

- 读请求不依赖钱包签名，通常可在未连接时也工作（只要 RPC 可读）

---

### `components/WriteContract.tsx`

**作用**：提交 `setValue(uint256)` 写交易。

**核心逻辑**：

1. 输入校验（空值、非整数、越界）
2. `useWriteContract` 发起交易请求（触发钱包确认）
3. 拿到 tx hash 后，`useWaitForTransactionReceipt` 等待确认
4. 显示 pending/success/error toast
5. 展示 tx hash + Sepolia Etherscan 链接
6. 错链保护：非 Sepolia 禁用提交并提示 `Please switch to Sepolia`

**学习点**：

- “发起交易”和“交易确认”是两个阶段
- 要分别管理 UI 状态与提示

---

### `components/EventList.tsx`

**作用**：展示 `ValueChanged` 事件（历史 + 实时）。

**核心逻辑**：

- 历史：`publicClient.getLogs(...)`
  - 拉取最近窗口（lookback）内日志
  - 截取最新 N 条（当前 50）
- 实时：`useWatchContractEvent(...)`
  - 收到新日志后追加到列表
- 去重：使用 `txHash + logIndex` 作为唯一 key
- 支持手动刷新按钮
- 空态显示 `No events yet`

**学习点**：

- 历史拉取 + 实时监听是常见事件列表组合模式

---

## 4.3 `config/` 目录

### `config/contracts.ts`

**作用**：合约单一真相源（Single Source of Truth）。

**导出内容**：

- `CONTRACT_ADDRESS`
- `CONTRACT_CHAIN`（sepolia）
- `CONTRACT_CHAIN_ID`
- `CONTRACT_ABI`（`as const`）

**为什么重要**：

- 所有组件统一引用这里，避免散落常量导致错配
- `as const` 让 TypeScript 精确推断函数名/参数类型

---

### `config/wagmi.ts`

**作用**：wagmi + RainbowKit 连接配置。

**核心内容**：

- `chains = [sepolia]`
- `connectorsForWallets(...)` 配置常见钱包
- `createConfig({ chains, connectors, transports })`
- `http(process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL)` 指定 RPC

**学习点**：

- 这就是 dApp “链连接层”的配置中心

---

## 4.4 根目录配置文件

### `.env.example`

**作用**：环境变量示例模板。

包含：

- `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`
- `NEXT_PUBLIC_SEPOLIA_RPC_URL`

复制为 `.env.local` 后填你的真实值。

---

### `package.json`

**作用**：项目依赖与脚本清单。

关键 scripts：

- `npm run dev`：开发模式
- `npm run build`：生产构建
- `npm run start`：运行构建产物

---

### `package-lock.json`

**作用**：锁定依赖树版本，保证团队安装一致。

---

### `tsconfig.json`

**作用**：TypeScript 编译配置。

关键点：

- 路径别名 `@/*`
- 适配 Next.js 的 TS 选项
- 目标版本支持 BigInt（用于链上数值）

---

### `tailwind.config.ts`

**作用**：Tailwind 扫描路径与主题配置。

当前扫描：`app/**/*` 与 `components/**/*`。

---

### `postcss.config.js`

**作用**：Tailwind 编译链配置（postcss + autoprefixer）。

---

### `next.config.ts`

**作用**：Next.js 运行配置。

当前仅开启 `reactStrictMode`。

---

### `next-env.d.ts`

**作用**：Next.js 自动生成的 TS 类型声明文件，不需要手改。

---

### `README.md`

**作用**：给使用者的快速上手说明（安装、运行、常见问题）。

---

### `PROJECT_GUIDE.md`（本文件）

**作用**：给学习者的“代码级讲解文档”。

---

## 4.5 自动生成目录（学习时知道即可）

### `.next/`

- Next.js 构建输出目录
- 包含编译后的 server/client 产物、清单文件、缓存
- 删除后会在下次 `npm run dev`/`npm run build` 重新生成

### `node_modules/`

- npm 依赖安装目录
- 体积大、文件多，不需要逐个阅读

---

## 5. 页面功能与文件映射

- 连接钱包：`components/ConnectSection.tsx`
- 读取数值：`components/ReadContract.tsx`
- 写入数值：`components/WriteContract.tsx`
- 事件历史与实时：`components/EventList.tsx`
- Provider 注入：`components/Providers.tsx`
- 合约配置：`config/contracts.ts`
- 链与钱包配置：`config/wagmi.ts`
- 页面组装：`app/page.tsx`

---

## 6. 你可以按这个顺序学习源码

1. `config/contracts.ts`（先看合约定义）
2. `config/wagmi.ts`（再看链连接）
3. `components/Providers.tsx`（看上下文注入）
4. `ConnectSection`（最容易理解）
5. `ReadContract`（读调用）
6. `WriteContract`（交易完整流程）
7. `EventList`（日志历史 + 实时）
8. `app/page.tsx` 与 `layout.tsx`（整体拼装）

---

## 7. 常见改造点（学习下一步）

- 替换真实合约地址与 ABI：`config/contracts.ts`
- 增加 `switchNetwork` 按钮（从提示升级为一键切链）
- 写入成功后自动触发读取刷新
- 事件列表添加时间戳（按 block 再查时间）
- 接入 Zustand/Context 做全局链状态管理（进阶）

---

如果你愿意，我下一步可以再给你一版“按函数逐行解释”的文档（例如逐行讲 `WriteContract.tsx` 和 `EventList.tsx` 的每段代码在做什么）。
