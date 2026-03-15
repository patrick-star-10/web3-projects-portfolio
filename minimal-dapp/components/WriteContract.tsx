'use client';

import { FormEvent, useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi';
// 引入合约相关的常量配置
import { CONTRACT_ABI, CONTRACT_ADDRESS, CONTRACT_CHAIN, CONTRACT_CHAIN_ID } from '@/config/contracts';

const UINT256_MAX = (1n << 256n) - 1n;// uint256 的最大值，用于输入验证
// 解析用户输入的字符串为 uint256，返回 BigInt 或 null（无效输入）
function parseUint256(input: string) {
  if (!input) return null;// 空输入视为无效
  if (!/^\d+$/.test(input)) return null;// 仅允许数字字符，其他字符视为无效
  const value = BigInt(input);// 转换为 BigInt 进行范围检查
  if (value < 0n || value > UINT256_MAX) return null;// 超出 uint256 范围视为无效
  return value;
}

// 将交易哈希缩短为前10和后8字符，中间用省略号连接，便于展示
function shortenHash(hash: string) {
  return `${hash.slice(0, 10)}...${hash.slice(-8)}`;
}

export function WriteContract() {
  const [value, setValue] = useState('');
  const pendingToastIdRef = useRef<string | number | null>(null);
  const lastErrorRef = useRef<string | null>(null);// 记录上一次错误消息，避免重复显示相同错误
  const { chainId, isConnected } = useAccount();
  // 使用 wagmi 的 useWriteContract 钩子准备调用合约方法，获取交易哈希、调用函数和错误状态
  const { data: hash, writeContract, isPending, error: writeError } = useWriteContract();
  // 使用 useWaitForTransactionReceipt 钩子监听交易状态，获取是否正在确认、是否成功和确认错误状态
  const {
    isLoading: isConfirming,
    isSuccess,
    error: receiptError,
  } = useWaitForTransactionReceipt({
    hash,// 监听指定交易哈希的状态变化
    chainId: CONTRACT_CHAIN_ID,// 确保监听正确链上的交易
    query: {
      enabled: Boolean(hash),// 只有在有交易哈希时才启用监听，避免不必要的查询和状态更新
    },
  });
  const isWrongChain = isConnected && chainId !== CONTRACT_CHAIN_ID;// 用户已连接但不在正确链上时，视为链错误
  const isSubmitDisabled = isWrongChain || isPending || isConfirming;// 当链错误、交易待处理或交易确认中时，禁用提交按钮，避免用户重复提交或提交无效交易

  const onSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();//阻止表单默认提交行为，使用自定义逻辑处理提交事件
    if (isWrongChain) {
      toast.error(`Please switch to ${CONTRACT_CHAIN.name}`);//如果用户在错误链上，显示错误提示并阻止提交
      return;
    }

    // 解析用户输入的值，进行有效性检查，如果无效则显示错误提示并阻止提交
    const parsedValue = parseUint256(value.trim());
    if (parsedValue === null) {
      toast.error('请输入有效的 uint256(非负整数)');
      return;
    }

    // 调用 writeContract 函数提交交易，传入合约地址、ABI、函数名、参数和链ID等必要信息，如果调用失败则显示错误提示
    try {
      writeContract({
        address: CONTRACT_ADDRESS,
        abi: CONTRACT_ABI,
        functionName: 'setValue',
        args: [parsedValue],// 将解析后的 uint256 值作为参数传递给合约函数
        chainId: CONTRACT_CHAIN_ID,
      });
    } catch {
      toast.error('提交交易失败');
    }
  };

  useEffect(() => {
    // 根据交易状态变化显示不同的 toast 提示，确保用户及时了解交易进展和结果
    if (hash && (isPending || isConfirming) && pendingToastIdRef.current == null) {
      pendingToastIdRef.current = toast.loading('交易已提交，等待确认...');
    }

    // 当交易确认成功时，如果之前有待处理的 toast，则更新该 toast 显示成功消息并重置pendingToastIdRef和lastErrorRef，清空输入框
    if (isSuccess && pendingToastIdRef.current != null) {
      toast.success('交易确认成功', { id: pendingToastIdRef.current });
      pendingToastIdRef.current = null;
      setValue('');
      lastErrorRef.current = null;
    }
    // 优先显示 writeContract 调用错误，如果没有则显示交易确认错误，避免重复显示相同错误消息
    const errorMessage = writeError?.message ?? receiptError?.message ?? null;
    // 当有新的错误消息且与上一次不同，且当前有待处理的 toast 时，更新该 toast 显示错误消息，并重置 pendingToastIdRef 和 lastErrorRef
    if (errorMessage && errorMessage !== lastErrorRef.current && pendingToastIdRef.current != null) {
      toast.error(errorMessage, {
        id: pendingToastIdRef.current,
      });
      pendingToastIdRef.current = null;
      lastErrorRef.current = errorMessage;
    }
    // 当有新的错误消息且与上一次不同，且当前没有待处理的 toast 时，直接显示错误消息，并更新 lastErrorRef 以避免重复显示相同错误
    if (errorMessage && errorMessage !== lastErrorRef.current && pendingToastIdRef.current == null) {
      toast.error(errorMessage);
      lastErrorRef.current = errorMessage;
    }// 依赖项包括交易哈希、交易状态和错误状态，确保在这些状态变化时正确更新 toast 提示，避免遗漏重要的用户反馈
  }, [hash, isPending, isConfirming, isSuccess, writeError, receiptError]);

  return (
    <section className="ui-card">
      <h2 className="mb-3 ui-title">写入合约值</h2>

      {isWrongChain ? (
        <p className="mb-3 rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-800">
          Please switch to {CONTRACT_CHAIN.name}
        </p>
      ) : null}

      <form onSubmit={onSubmit} className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <input
          type="number"
          min="0"
          step="1"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder="输入 uint256 数值"
          className="ui-input"
        />
        <button
          type="submit"
          disabled={isSubmitDisabled}
          className="ui-btn-primary"
        >
          {isPending || isConfirming ? '处理中...' : 'Set Value'}
        </button>
      </form>

      {hash ? (
        <div className="mt-3 space-y-1 text-xs text-slate-600">
          <p>
            Tx Hash: <span className="font-mono">{shortenHash(hash)}</span>
          </p>
          <p className="text-xs text-slate-500">
            本地 Anvil 交易不提供 Etherscan 链接。
          </p>
        </div>
      ) : null}
    </section>
  );
}
