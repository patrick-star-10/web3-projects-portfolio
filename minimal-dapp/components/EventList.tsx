'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { formatUnits } from 'viem';
import { usePublicClient, useWatchContractEvent } from 'wagmi';

import { CONTRACT_ABI, CONTRACT_ADDRESS, CONTRACT_CHAIN_ID } from '@/config/contracts';

type ValueChangedItem = {
  key: string;
  blockNumber?: bigint;
  txHash?: string;
  logIndex?: number;
  value: bigint;
};

const MAX_ITEMS = 50;  // 定义事件列表中最多展示的事件数量，避免列表过长导致性能问题和用户体验下降
const LOOKBACK_BLOCKS = 50_000n;  // 定义加载历史事件时回溯的区块数量，确保能够获取到足够的历史事件数据，同时避免查询过多区块导致性能问题

export function EventList() {
  const publicClient = usePublicClient({ chainId: CONTRACT_CHAIN_ID });// 取指定链ID的公共客户端实例
  const [events, setEvents] = useState<ValueChangedItem[]>([]);// 事件列表的状态，存储从链上获取的 ValueChanged 事件数据，每个事件包含唯一键、区块号、交易哈希、日志索引和事件参数值等信息
  const [isRefreshing, setIsRefreshing] = useState(false);// 显示UI的刷新状态
  const [error, setError] = useState<string | null>(null);// 错误状态的状态，存储加载事件数据过程中可能发生的错误信息，便于在 UI 中显示错误提示

  
  const loadHistory = useCallback(async () => {
    if (!publicClient) return; // 如果公共客户端不可用，直接返回
    setIsRefreshing(true);  // 开始加载，设置刷新状态为 true，显示加载指示器
    setError(null); // 重置错误状态，清除之前可能存在的错误信息

    try {
      const latestBlock = await publicClient.getBlockNumber();// 查询当前最新区块号
      // 计算查询事件的起始区块号，确保不会查询过多区块导致性能问题，同时能够获取到足够的历史事件数据
      const fromBlock = latestBlock > LOOKBACK_BLOCKS ? latestBlock - LOOKBACK_BLOCKS : 0n;

      // 查询指定区块范围内的 ValueChanged 事件日志，获取事件数据列表
      const logs = await publicClient.getLogs({
        address: CONTRACT_ADDRESS,
        event: CONTRACT_ABI[2],
        fromBlock,//查询的起始区块号
        toBlock: 'latest',// 查询到最新区块，确保获取到最新的事件数据
      });

      const mapped = logs
        .slice(-MAX_ITEMS)
        .reverse()// 事件列表按照时间顺序展示，最新事件在前，历史事件在后
        .map((log) => ({
          key: `${log.transactionHash ?? 'pending'}-${log.logIndex ?? -1}`,
          blockNumber: log.blockNumber,
          txHash: log.transactionHash,
          logIndex: log.logIndex,
          value: log.args?.newValue ?? 0n,
        }));

      setEvents(mapped);// 更新事件列表状态，在UI上展示从链上获取的历史事件数据
    } catch (e) {
      setError(e instanceof Error ? e.message : '获取事件失败');// 如果加载事件数据过程中发生错误，更新错误状态，在UI上显示错误提示信息
    } finally {
      setIsRefreshing(false);// 加载完成，设置刷新状态为 false，隐藏加载指示器
    }
  }, [publicClient]);// 确保loadHistory总是使用最新的客户端

  useEffect(() => {
    void loadHistory();// 组件挂载时自动加载历史事件数据，确保用户打开页面时能够看到最新的事件列表
  }, [loadHistory]); // 依赖 loadHistory，确保在公共客户端变化时重新加载事件数据 


  useWatchContractEvent({
    address: CONTRACT_ADDRESS,
    abi: CONTRACT_ABI,
    eventName: 'ValueChanged',
    chainId: CONTRACT_CHAIN_ID,
    
    onLogs(logs) {    // 监听到新的 ValueChanged 事件日志时的回调函数，接收事件日志数据列表作为参数
      setEvents((prev) => {
        const incoming = logs.map((log) => ({
          key: `${log.transactionHash ?? 'pending'}-${log.logIndex ?? -1}`,
          blockNumber: log.blockNumber,
          txHash: log.transactionHash,
          logIndex: log.logIndex,
          value: log.args.newValue ?? 0n,
        }));

        const next = [...incoming.reverse(), ...prev];// 将新事件添加到列表前面，保持事件列表按照时间顺序展示，最新事件在前，历史事件在后
        // 去重事件列表，确保同一事件不会重复展示，避免由于监听到重复事件日志导致事件列表中出现重复项
        const unique = Array.from(new Map(next.map((item) => [item.key, item])).values());
        return unique.slice(0, MAX_ITEMS);// 保持事件列表中最多展示 MAX_ITEMS 条事件，避免列表过长导致性能问题和用户体验下降
      });
    },
  });

  const total = useMemo(() => events.length, [events]);

  return (
    <section className="ui-card">
      <div className="mb-3 flex items-center justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-slate-900">ValueChanged 事件</h2>
          <p className="text-sm text-slate-600">展示最新 {total} 条（历史 + 实时）</p>
        </div>
        <button
          type="button"
          onClick={() => void loadHistory()}
          disabled={isRefreshing}
          className="ui-btn disabled:cursor-not-allowed disabled:opacity-60"
        >
          {isRefreshing ? '刷新中...' : '刷新'}
        </button>
      </div>

      {error ? <p className="mb-2 text-sm text-red-600">加载失败：{error}</p> : null}

      {events.length === 0 && !isRefreshing ? (
        <p className="text-sm text-slate-500">No events yet</p>
      ) : (
        <ul className="space-y-2">
          {events.map((event) => (
            <li
              key={event.key}
              className="rounded-xl border border-slate-200/80 bg-white/75 p-3 text-sm shadow-[0_8px_20px_-16px_rgba(15,23,42,0.35)]"
            >
              <p>
                <span className="font-semibold">newValue:</span> {formatUnits(event.value, 0)}
              </p>
              <p className="text-xs text-slate-600">block: {event.blockNumber?.toString() ?? '-'}</p>
              <p className="text-xs text-slate-600">logIndex: {event.logIndex ?? '-'}</p>
              <p className="break-all font-mono text-xs text-slate-600">tx: {event.txHash ?? '-'}</p>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
