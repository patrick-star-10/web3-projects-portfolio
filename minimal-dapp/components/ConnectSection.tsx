'use client';// 表示是客户端组件用来和用户交互

import { ConnectButton } from '@rainbow-me/rainbowkit';//从rainbowkit库中导入ConnectButton组件，用于连接钱包
import { useAccount, useDisconnect } from 'wagmi';//从wagmi库中导入useAccount和useDisconnect钩子，用于获取账户信息和断开连接功能
import { CONTRACT_CHAIN, CONTRACT_CHAIN_ID } from '@/config/contracts';//从配置文件中导入合约所在链的信息，包括链ID和名称

// 定义一个函数用于缩短以太坊地址显示，保留前6位和后4位，中间用...代替
function shortenAddress(address?: string) {
  if (!address) return '未连接';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function ConnectSection() {
  const { address, chain, status, isConnected } = useAccount();
  const { disconnect } = useDisconnect();
  //定义isWrongChain，用于判断当前连接的链是否与配置的合约链ID不匹配，如果不匹配则提示用户切换网络
  const isWrongChain = isConnected && chain?.id !== CONTRACT_CHAIN_ID;
  return (
    <section className="ui-card">
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <ConnectButton chainStatus="name" accountStatus="address" showBalance={false} />
        {/*动态渲染，三元运算符表示，只有当钱包链接的时候才会显示断开按钮 */}
        {address ? (
          <button
            type="button"
            onClick={() => disconnect()}
            className="ui-btn"
          >
            断开连接
          </button>
        ) : null}
      </div>
      
      {/*如果当前连接的链与配置的合约链ID不匹配，则显示一个警告提示用户切换网络*/}
      {isWrongChain ? (
        <div className="mb-3 rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-800">
          当前网络不是 {CONTRACT_CHAIN.name}，请切换到 {CONTRACT_CHAIN.name}(chainId: {CONTRACT_CHAIN_ID})。
        </div>
      ) : null}

      <div className="grid gap-2 rounded-xl border border-slate-200/70 bg-white/70 p-3 text-sm text-slate-700 sm:grid-cols-3">
        <p>
          <span className="font-semibold">连接状态：</span>
          {status}
        </p>
        <p>
          <span className="font-semibold">地址：</span>
          {shortenAddress(address)}
        </p>
        <p>
          <span className="font-semibold">当前链：</span>
          {chain ? `${chain.name} (${chain.id})` : '未知'}
        </p>
      </div>
    </section>
  );
}
