'use client';
// 导入 RainbowKit 的默认样式，确保应用中的钱包连接组件能够正确显示和使用 RainbowKit 提供的 UI 样式
import '@rainbow-me/rainbowkit/styles.css';
//	RainbowKitProvider 会把 钱包状态（连接/断开、钱包地址、链信息） 传递给子组件。
import { RainbowKitProvider } from '@rainbow-me/rainbowkit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';// 导入 QueryClient 和 QueryClientProvider 组件，用于在应用中提供 React Query 的上下文，确保应用中的数据获取和缓存功能能够正确使用 React Query 提供的功能
import { useState } from 'react';
import { WagmiProvider } from 'wagmi';// 导入 WagmiProvider 组件，用于在应用中提供 wagmi 的上下文，确保应用中的链连接和合约交互功能能够正确使用 wagmi 提供的功能
import { Toaster } from 'sonner';

import { wagmiConfig } from '@/config/wagmi';// 导入之前定义的 wagmi 配置，包含链信息、连接器和传输设置，确保应用能够正确连接到链并与钱包进行交互，提供稳定的链上交互体验

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient()); // 创建一个 QueryClient 实例，并使用 useState 确保在组件生命周期内保持同一个实例，提供稳定的 React Query 上下文，避免不必要的重新创建和性能问题

  // 使用 WagmiProvider 包裹整个应用，传入之前定义的 wagmiConfig，确保应用中的链连接和合约交互功能能够正确使用 wagmi 提供的功能
  // 在 WagmiProvider 内部使用 QueryClientProvider 包裹应用，传入之前创建的 queryClient 实例，确保应用中的数据获取和缓存功能能够正确使用 React Query 提供的功能
  // 在 QueryClientProvider 内部使用 RainbowKitProvider 包裹应用，确保应用中的钱包连接组件能够正确显示和使用 RainbowKit 提供的 UI 样式
  // 在 RainbowKitProvider 内部渲染 children 和 Toaster 组件，确保应用中的子组件能够访问到 wagmi 和 RainbowKit 的上下文，并且能够显示全局的通知提示
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          {children}
          <Toaster richColors position="top-right" />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
