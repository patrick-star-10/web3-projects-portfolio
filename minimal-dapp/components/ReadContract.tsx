'use client';

import { useReadContract } from 'wagmi';// 从 wagmi 库中导入 useReadContract 钩子，用于读取智能合约数据

import { CONTRACT_ABI, CONTRACT_ADDRESS, CONTRACT_CHAIN_ID } from '@/config/contracts';// 从配置文件中导入合约的 ABI、地址和链 ID 信息

export function ReadContract() {
  {/* 读取合约值 */}
  const { data, error, isLoading, isError, isFetching, refetch } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: CONTRACT_ABI,
    functionName: 'getValue',
    chainId: CONTRACT_CHAIN_ID,
  });

  return (
    <section className="ui-card">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="ui-title">读取合约值</h2>
        <button
          type="button"
          onClick={() => refetch()}
          disabled={isFetching}
          className="ui-btn"
        >
          {isFetching ? '刷新中...' : '刷新'}     {/* 按钮显示的内容 */}
        </button>
      </div>

      {isLoading && <p className="ui-subtle">读取中...</p>}
      {isError && (
        <p className="text-sm text-red-600">
          读取失败：{error?.shortMessage ?? error?.message ?? '请检查网络或合约地址。'}
        </p>
      )}
      {/* 只有当不在加载状态且没有错误时才显示数据，如果数据不存在则显示 '0' 作为默认值 */}
      {!isLoading && !isError && (
        <p className="text-2xl font-bold text-slate-900">{data?.toString() ?? '0'}</p>
      )}
    </section>
  );
}
