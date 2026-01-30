# TokenBank V2 - Hook Callback + EIP-7702 批量执行

增强版代币银行，支持多种存款方式：Hook回调一步存款、EIP-7702批量执行。

## 特性

- **transferWithCallback**: 一步完成存款（V2 Hook回调模式）
- **EIP-5792 + EIP-7702 批量执行**: 使用 `useSendCalls` 在一个交易中完成 approve + deposit
- **自动智能账户升级**: MetaMask 自动引导用户升级 EOA 到智能账户
- **ITokenReceiver Hook**: 智能合约回调接口  
- **向后兼容**: 仍支持标准 approve + deposit
- Next.js 16 前端
- 实时余额显示

## 快速开始

```bash
# 前端
cd frontend && npm install && npm run dev

# 合约
cd contracts && forge build
```

## 已部署合约 (Sepolia)

- MyTokenV2: `0xCD0262E3459d4D2B809f0EBC5054b7eA778dd573` ([Etherscan](https://sepolia.etherscan.io/address/0xCD0262E3459d4D2B809f0EBC5054b7eA778dd573))
- TokenBankV2: `0x6ebDC5f380009016D0d1FCeCA8372542a9c79043` ([Etherscan](https://sepolia.etherscan.io/address/0x6ebDC5f380009016D0d1FCeCA8372542a9c79043))
- MetaMask Delegator: `0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B` (官方部署)

**部署者**: `0x5aba664d6532973C921A6533E20a35438f2E5A40`

### 测试交易记录

- **EIP-7702 批量存款交易**: [`0xf6df2c554bfbf6b0e74036745255381d451fbf4d80dcc99e2535fece2984c965`](https://sepolia.etherscan.io/tx/0xf6df2c554bfbf6b0e74036745255381d451fbf4d80dcc99e2535fece2984c965)
  - 在一个交易中完成了 approve + deposit 操作

---

## EIP-7702 功能说明

### 什么是 EIP-7702？

EIP-7702 是以太坊的一个重要升级，允许EOA（外部拥有账户）临时将智能合约代码映射到自己的地址。这意味着普通的以太坊账户可以在单个交易中执行智能合约功能，如批量操作。

### 实现方式：EIP-5792 + EIP-7702

**重要说明**：MetaMask 不直接暴露 `eth_signAuthorization` RPC 方法给 DApp。正确的实现方式是使用 **EIP-5792** 的 `wallet_sendCalls` API（在 Wagmi 中是 `useSendCalls` hook）。

当 DApp 发送批量交易请求时，MetaMask 会自动：
1. 检测是否需要升级 EOA 到智能账户
2. 如果需要，弹窗提示用户确认升级
3. 在后台处理 EIP-7702 授权
4. 执行批量交易

### 修改前后对比

**修改前（传统两步方式）：**
```typescript
// 需要两个独立的交易
// 交易 1: 授权
await token.approve(tokenBank, amount);
// 等待确认...

// 交易 2: 存款
await tokenBank.deposit(amount);
// 等待确认...
```

问题：
- 需要两次签名
- 两次 gas 费用
- 用户需要等待第一个交易确认
- 存在 approve 后 deposit 前的风险窗口

**修改后（EIP-5792 + EIP-7702 批量执行）：**
```typescript
import { useSendCalls } from 'wagmi';

// 使用 useSendCalls hook
const { sendCalls, data, isPending, isSuccess } = useSendCalls();

// 发送批量交易请求
sendCalls({
  calls: [
    // 第一个调用：approve
    {
      to: tokenAddress,
      abi: TOKEN_ABI,
      functionName: 'approve',
      args: [tokenBankAddress, amount],
    },
    // 第二个调用：deposit
    {
      to: tokenBankAddress,
      abi: TOKEN_BANK_ABI,
      functionName: 'deposit',
      args: [amount],
    },
  ],
});

// MetaMask 会自动：
// 1. 检测用户是否需要升级到智能账户
// 2. 弹窗提示用户确认（首次使用时）
// 3. 原子执行所有操作
```

优势：
- 一次签名，一次 gas 费用
- 更好的用户体验（钱包自动处理升级流程）
- 原子执行，全部成功或全部回滚
- 消除 approve 后的风险窗口
- DApp 代码更简洁

### 工作原理

1. **EIP-5792 (Wallet Call API)**：标准化的钱包批量调用接口，DApp 通过 `useSendCalls` 发送批量交易请求。

2. **智能账户升级**：用户首次使用批量交易时，MetaMask 会弹窗提示"升级到智能账户"。确认后，EIP-7702 授权自动完成。

3. **原子执行**：所有操作在一个交易中顺序执行，第二个操作可以依赖第一个操作的结果。

4. **查询状态**：使用 `getCallsStatus` 查询批量交易状态，获取交易哈希。

### MetaMask Delegator 合约

- **地址**: `0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B`
- **类型**: EIP7702StatelessDeleGator（无状态设计）
- **特点**: 
  - 不存储任何用户数据
  - EOA 仍完全由用户控制
  - 实现 EIP-7821 接口（Minimal Batch Executor）
  - MetaMask 在后台自动使用此合约

### 为什么使用 useSendCalls 而不是直接调用 eth_signAuthorization

| 方式 | 说明 |
|------|------|
| `eth_signAuthorization` | MetaMask 不直接暴露此 RPC 方法给 DApp |
| `useSendCalls` (EIP-5792) | 标准化接口，钱包自动处理底层授权 |

使用 `useSendCalls` 的好处：
- 代码更简洁，不需要手动构建 `executeBatch` 调用
- 钱包负责处理 EIP-7702 授权，对 DApp 透明
- 更好的用户体验，钱包自动引导升级流程

---

## 如何替换为你自己的合约

### 步骤 1: 部署合约

```bash
cd contracts
cp .env.example .env
# 编辑 .env 填入 PRIVATE_KEY 和 SEPOLIA_RPC_URL

forge build
forge script script/DeployV2.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --legacy
```

记录输出的合约地址。

### 步骤 2: 导出 ABI

```bash
cat out/MyTokenV2.sol/MyTokenV2.json | jq '.abi' > ../frontend/src/constants/MyTokenV2.abi.json
cat out/TokenBankV2.sol/TokenBankV2.json | jq '.abi' > ../frontend/src/constants/TokenBankV2.abi.json
```

### 步骤 3: 更新前端

编辑 `frontend/src/constants/addresses.ts`:
```typescript
export const CONTRACTS = {
  MyTokenV2: '0x你的地址',
  TokenBankV2: '0x你的地址',
} as const;
```

编辑 `frontend/src/constants/abis.ts` 导入新的 ABI。

### 步骤 4: 测试

```bash
cd frontend && npm run dev
```

访问 http://localhost:3000 测试功能：
- `/` - TokenBank V2（Hook 回调模式）
- `/eip7702` - EIP-7702 批量执行模式

---

## 核心改进对比

| 功能 | 传统方式 | V2 Hook | EIP-5792 + EIP-7702 |
|------|----------|---------|---------------------|
| 交易数量 | 2 | 1 | 1 |
| 需要approve | 是 | 否 | 是（但合并执行）|
| 原子性 | 否 | 是 | 是 |
| 合约修改 | 无 | 需要 | 无需修改 |
| 钱包支持 | 所有 | 所有 | 需要支持EIP-5792/7702 |
| DApp 复杂度 | 低 | 低 | 低（钱包处理底层）|

**V1 (两步)**:
1. approve(bank, amount)
2. deposit(amount)

**V2 (一步 - Hook回调)**:
```solidity
token.transferWithCallback(bank, amount)
```

**EIP-5792 + EIP-7702 (一步 - 批量执行)**:
```typescript
// 使用 Wagmi 的 useSendCalls hook
sendCalls({
  calls: [
    { to: token, abi, functionName: 'approve', args: [...] },
    { to: bank, abi, functionName: 'deposit', args: [...] },
  ],
});
// MetaMask 自动处理 EIP-7702 升级和批量执行
```

---

## 技术栈

**合约**: Solidity 0.8.20, Foundry, OpenZeppelin  
**前端**: Next.js 16, TypeScript, Wagmi v2, RainbowKit, Viem  
**批量交易**: EIP-5792 (useSendCalls), EIP-7702, MetaMask Delegator

## 相关资源

- [EIP-7702 规范](https://eips.ethereum.org/EIPS/eip-7702)
- [EIP-5792 规范 (Wallet Call API)](https://eips.ethereum.org/EIPS/eip-5792)
- [MetaMask 升级 EOA 到智能账户教程](https://docs.metamask.io/tutorials/upgrade-eoa-to-smart-account)
- [MetaMask Delegation Framework](https://github.com/MetaMask/delegation-framework)
- [Wagmi useSendCalls 文档](https://wagmi.sh/react/api/hooks/useSendCalls)
- [EIP-7821 (Minimal Batch Executor)](https://eips.ethereum.org/EIPS/eip-7821)

## License

MIT
