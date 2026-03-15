import './globals.css';// 全局样式文件，包含基础样式和UI组件的样式定义

import type { Metadata } from 'next';// Next.js的元数据类型定义，用于定义页面的标题、描述等信息

import { Providers } from '@/components/Providers';// Providers组件，封装了Wagmi和RainbowKit的Provider，提供全局的Web3上下文支持
// 引入必要的组件和类型定义，包括全局样式、元数据类型和Providers组件
export const metadata: Metadata = {
  title: 'Minimal DApp',
  description: 'Wagmi + Viem + RainbowKit on Sepolia',
};
// 定义页面的元数据，包括标题和描述，供搜索引擎和浏览器使用
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body className="min-h-screen antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
