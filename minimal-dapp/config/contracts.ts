import { foundry } from 'wagmi/chains';

export const CONTRACT_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as const;
export const CONTRACT_CHAIN = foundry;
export const CONTRACT_CHAIN_ID = foundry.id;
// 合约 ABI 定义了合约的接口，包括函数和事件的名称、参数类型、返回值类型等信息，确保前端应用能够正确调用合约方法和监听事件
export const CONTRACT_ABI = [    
  {
    type: 'function',
    name: 'getValue',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'setValue',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_value', type: 'uint256' }],
    outputs: [],
  },
  {
    type: 'event',
    name: 'ValueChanged',
    inputs: [{ name: 'newValue', type: 'uint256', indexed: false }],
    anonymous: false,
  },
  
] as const;//转化为只读类型，确保在代码中不会意外修改这些常量值，增加代码的安全性和可维护性
