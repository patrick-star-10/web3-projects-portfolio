import { connectorsForWallets } from '@rainbow-me/rainbowkit';// 导入 RainbowKit 提供的 connectorsForWallets 函数，用于根据指定的钱包配置创建连接器，支持多种钱包类型，方便用户连接他们喜欢的钱包进行交互
import {
  coinbaseWallet,
  injectedWallet,
  metaMaskWallet,
  rainbowWallet,
  walletConnectWallet,
} from '@rainbow-me/rainbowkit/wallets';
import { createConfig, http } from 'wagmi';// 导wagmi的createConfig 函数和 http 传输函数，用于创建全局配置和设置链的 RPC 连接
import { foundry } from 'wagmi/chains';// 导入自定义的 Foundry 链配置，包含链ID、名称、RPC URL等信息，确保应用连接到正确的链

// 从环境变量中获取 WalletConnect 项目ID，如果未设置则使用默认值 'demo-project-id'，确保连接器配置正确，支持 WalletConnect 协议的钱包连接
const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ?? 'demo-project-id';
const chains = [foundry] as const;// 定义支持的链列表，这里只包含自定义的 Foundry 链，确保应用只连接到指定的链，避免用户连接到不受支持的链

// 使用 connectorsForWallets 函数创建连接器，传入钱包配置和应用信息，支持多种主流钱包类型，提供良好的用户体验和广泛的兼容性
const connectors = connectorsForWallets(
  [
    {
      groupName: 'Recommended',
      wallets: [
        injectedWallet,
        metaMaskWallet,
        rainbowWallet,
        coinbaseWallet,
        walletConnectWallet,
      ],
    },
  ],
  {
    appName: 'Minimal DApp',
    projectId,// 将之前获取的 WalletConnect 项目ID传入连接器配置，确保 WalletConnect 协议的钱包连接能够正确识别和授权应用，提供稳定的连接体验
  }
);

// 创建 wagmi 配置，包含链信息、连接器和传输设置，确保应用能够正确连接到链并与钱包进行交互，提供稳定的链上交互体验
export const wagmiConfig = createConfig({
  chains,
  connectors,// 使用之前创建的连接器，支持多种钱包连接方式，满足不同用户的需求
  transports: {// 配置链的 RPC 连接，使用 http 传输函数，并从环境变量中获取 RPC URL，如果未设置则使用默认的本地 Anvil URL，确保应用能够正确连接到链进行交互
    [foundry.id]: http(process.env.NEXT_PUBLIC_LOCAL_RPC_URL ?? 'http://127.0.0.1:8545'),
  },
});
