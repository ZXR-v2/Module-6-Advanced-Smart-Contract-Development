# TokenBank V2 智能合约

TokenBank V2 是一个支持 Hook 回调的代币银行合约，配合 EIP-7702 可以实现更高效的存款操作。

## 合约说明

### MyTokenV2.sol
扩展 ERC20 代币，添加 `transferWithCallback` 函数，支持转账时自动触发接收合约的回调。

### TokenBankV2.sol
扩展 TokenBank，实现 `ITokenReceiver` 接口，支持通过 `transferWithCallback` 直接存款。

## 已部署合约 (Sepolia)

- **MyTokenV2**: `0x2023Bb8d3e166fcA393BB1D1229E74f5D47939e0`
- **TokenBankV2**: `0x2219d42014E190D0C4349A6A189f4d11bc92669B`

## EIP-7702 集成说明

### 什么是 EIP-7702？

EIP-7702 允许 EOA（外部拥有账户）临时将智能合约代码映射到自己的地址，从而获得智能合约的功能（如批量执行）。

### MetaMask Delegator 合约

MetaMask 官方部署的 `EIP7702StatelessDeleGator` 合约：
- **地址**: `0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B`
- **GitHub**: https://github.com/MetaMask/delegation-framework

### 工作原理

1. **签署 EIP-7702 授权**: 用户签署授权，将 Delegator 合约代码映射到自己的 EOA
2. **调用 executeBatch**: EOA 现在可以调用 `executeBatch` 函数批量执行操作
3. **原子执行**: approve + deposit 在一个交易中完成

### 代码示例

```solidity
// Delegator 合约的 executeBatch 函数签名
function executeBatch(Execution[] calldata executions) external payable;

// Execution 结构体
struct Execution {
    address target;   // 目标合约地址
    uint256 value;    // 发送的 ETH 数量
    bytes data;       // 调用数据
}
```

### 前端调用示例

```typescript
// 构建批量操作
const executions = [
  {
    target: tokenAddress,      // Token 合约
    value: 0n,
    data: approveCalldata,     // approve(tokenBank, amount)
  },
  {
    target: tokenBankAddress,  // TokenBank 合约
    value: 0n,
    data: depositCalldata,     // deposit(amount)
  },
];

// 签署授权并执行
const authorization = await walletClient.signAuthorization({
  contractAddress: '0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B',
  executor: 'self',
});

await walletClient.sendTransaction({
  authorizationList: [authorization],
  to: userAddress,
  data: encodeFunctionData({
    abi: EIP7702_DELEGATOR_ABI,
    functionName: 'executeBatch',
    args: [executions],
  }),
});
```

---

## Foundry 使用指南

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Deploy

```shell
forge script script/DeployV2.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --legacy
```

### Format

```shell
forge fmt
```

## 参考资料

- [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702)
- [MetaMask Delegation Framework](https://github.com/MetaMask/delegation-framework)
- [Foundry Book](https://book.getfoundry.sh/)
- [Viem EIP-7702](https://viem.sh/docs/eip7702)
