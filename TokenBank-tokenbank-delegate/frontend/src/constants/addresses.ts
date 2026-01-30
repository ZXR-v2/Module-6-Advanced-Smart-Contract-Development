// TokenBank V2 Contracts on Sepolia

export const CONTRACTS = {
  MyTokenV2: '0xCD0262E3459d4D2B809f0EBC5054b7eA778dd573',
  TokenBankV2: '0x6ebDC5f380009016D0d1FCeCA8372542a9c79043',
} as const;

// 为了兼容性保留 CONTRACTS_V2 别名
export const CONTRACTS_V2 = CONTRACTS;

// 旧版本合约（如果需要）
export const CONTRACTS_V1 = {
  MyToken: '0x0000000000000000000000000000000000000000',
  TokenBank: '0x0000000000000000000000000000000000000000',
} as const;

// Permit版本合约
export const CONTRACTS_PERMIT = {
  MyTokenPermit: '0x0000000000000000000000000000000000000000',
  TokenBankPermit: '0x0000000000000000000000000000000000000000',
} as const;

// Permit2版本合约
export const CONTRACTS_PERMIT2 = {
  MyToken: '0x0000000000000000000000000000000000000000',
  TokenBankPermit2: '0x0000000000000000000000000000000000000000',
  Permit2: '0x000000000022D473030F116dDEE9F6B43aC78BA3', // Uniswap Permit2 合约
} as const;

/**
 * ============================================================================
 * EIP-7702 相关合约地址
 * ============================================================================
 * 
 * 【修改说明 - EIP-7702 新增】
 * 
 * 原理：
 * EIP-7702 是以太坊的一个重要升级，允许EOA（外部拥有账户）临时将智能合约代码
 * 映射到自己的地址。这意味着普通的以太坊账户可以在单个交易中执行智能合约功能。
 * 
 * MetaMask Delegator 合约：
 * - 地址：0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B
 * - 这是MetaMask官方部署的EIP7702StatelessDeleGator合约
 * - 该合约实现了EIP-7821接口，支持批量执行功能（executeBatch）
 * - "Stateless"意味着它不在合约状态中存储签名者数据，使其更轻量和安全
 * 
 * 工作流程：
 * 1. 用户签署EIP-7702授权，将Delegator合约代码映射到自己的EOA
 * 2. 用户的EOA现在可以调用executeBatch函数
 * 3. executeBatch可以在一个交易中执行多个操作（如approve + deposit）
 * 4. 所有操作原子执行，要么全部成功，要么全部回滚
 * 
 * 优势：
 * - 将approve + deposit从2个交易合并为1个交易
 * - 减少gas费用和等待时间
 * - 保持原子性，避免approve后deposit失败的情况
 */
export const EIP7702_CONTRACTS = {
  // MetaMask官方的EIP-7702 Delegator合约（Stateless版本）
  // 在所有支持EIP-7702的网络上部署在相同地址
  MetaMaskDelegator: '0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B',
} as const;

export const EXPLORER_URL = 'https://sepolia.etherscan.io/tx/';
