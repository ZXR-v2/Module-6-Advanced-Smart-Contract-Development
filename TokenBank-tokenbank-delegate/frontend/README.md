# TokenBank V2 前端 - EIP-7702 批量执行

基于 Next.js 16 的 TokenBank DApp 前端，支持 EIP-7702 批量执行功能。

## 已部署合约 (Sepolia)

| 合约 | 地址 | Etherscan |
|------|------|-----------|
| MyTokenV2 | `0xCD0262E3459d4D2B809f0EBC5054b7eA778dd573` | [查看](https://sepolia.etherscan.io/address/0xCD0262E3459d4D2B809f0EBC5054b7eA778dd573) |
| TokenBankV2 | `0x6ebDC5f380009016D0d1FCeCA8372542a9c79043` | [查看](https://sepolia.etherscan.io/address/0x6ebDC5f380009016D0d1FCeCA8372542a9c79043) |
| MetaMask Delegator | `0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B` | [查看](https://sepolia.etherscan.io/address/0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B) |

**部署者**: `0x5aba664d6532973C921A6533E20a35438f2E5A40`

## 功能特性

### 1. TokenBank V2 (Hook回调)
- **路径**: `/`
- **功能**: 使用 `transferWithCallback` 一步完成存款
- **原理**: Token合约调用Bank的 `tokensReceived` 回调

### 2. EIP-7702 批量执行
- **路径**: `/eip7702`
- **功能**: 在一个交易中完成 approve + deposit
- **原理**: EOA签署EIP-7702授权，获得调用 `executeBatch` 的能力

## 快速开始

```bash
# 安装依赖
npm install

# 启动开发服务器
npm run dev
```

访问 [http://localhost:3000](http://localhost:3000)

## 技术栈

- **框架**: Next.js 16, React 19
- **Web3**: Wagmi v2, Viem, RainbowKit
- **样式**: Tailwind CSS v4
- **语言**: TypeScript

## 页面说明

| 路径 | 说明 | 存款方式 |
|------|------|----------|
| `/` | TokenBank V2 主页 | transferWithCallback (一步) |
| `/eip7702` | EIP-7702 批量执行 | executeBatch([approve, deposit]) |

## EIP-7702 工作原理

```
传统方式 (2个交易):
  交易1: approve(bank, amount)  →  等待确认
  交易2: deposit(amount)        →  等待确认

EIP-7702 (1个交易):
  1. 签署授权 (将Delegator代码映射到EOA)
  2. executeBatch([approve, deposit])
  3. 原子执行，全部成功或全部回滚
```

## 环境变量

创建 `.env.local` 文件：

```bash
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_project_id
```

## 相关资源

- [EIP-7702 规范](https://eips.ethereum.org/EIPS/eip-7702)
- [MetaMask Delegation Framework](https://github.com/MetaMask/delegation-framework)
- [Wagmi 文档](https://wagmi.sh/)
- [RainbowKit 文档](https://www.rainbowkit.com/)
