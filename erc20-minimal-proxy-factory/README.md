# Meme 代币发射平台 (最小代理模式)

这是一个使用 EIP-1167 最小代理模式实现的 Meme 代币发射平台。每个 Meme 是 ERC20 token，工厂合约通过最小代理创建实例，显著降低部署成本。费用按 **1% 项目方 / 99% 发行者** 自动分配。

## 功能特性
- ✅ 最小代理 (EIP-1167)，部署成本节省约 95%
- ✅ 自定义 `symbol / totalSupply / perMint / price`
- ✅ 费用自动分配：1% 项目方，99% 发行者
- ✅ 严格限制不超过总供应量
- ✅ ERC20 标准实现
- ✅ 完整测试覆盖

## 合约概览

### MemeFactory.sol
负责创建和管理 Meme 代币，提供两个核心方法：

```solidity
function deployMeme(
    string memory symbol,
    uint256 totalSupply,
    uint256 perMint,
    uint256 price
) external returns (address memeToken)
```

```solidity
function mintMeme(address tokenAddr) external payable
```

### MemeToken.sol
作为最小代理模板的 ERC20 实现，提供初始化、铸造与供应量控制。

## 快速开始

### 安装 Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 安装依赖与运行测试
```bash
cd erc20-minimal-proxy-factory
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge build
forge test -vvv
```

### 预期测试输出
```
Running 9 tests for test/MemeFactory.t.sol:MemeFactoryTest
Test result: ok. 9 passed; 0 failed; 0 skipped
```

## 使用示例

### 发行 Meme
```solidity
address memeToken = factory.deployMeme(
    "PEPE",
    1000000 * 1e18,
    1000 * 1e18,
    0.001 ether
);
```

### 铸造 Meme
```solidity
// perMint=1000, price=0.001 ETH => totalCost=1 ETH
factory.mintMeme{value: 1 ether}(memeToken);
```

## 费用计算公式
```
总费用 = (perMint * price) / 1e18
项目方费用 = 总费用 × 1%
发行者费用 = 总费用 × 99%
```

## 系统流程
```
1. 发行者调用 deployMeme()
2. 工厂克隆模板 (EIP-1167)
3. 初始化实例
4. 用户调用 mintMeme() 支付费用
5. 工厂分配 1% / 99%，并铸造 perMint 数量
```

## 关键验证点
- ✅ 费用分配比例正确（1% / 99%）
- ✅ 每次铸造数量正确
- ✅ 不超过 totalSupply

## 项目结构
```
erc20-minimal-proxy-factory/
├── src/
│   ├── MemeToken.sol
│   └── MemeFactory.sol
├── test/
│   └── MemeFactory.t.sol
├── script/
│   └── Deploy.s.sol
├── foundry.toml
└── README.md
```

## 部署到测试网（可选）
```bash
export PRIVATE_KEY="your_private_key"
export SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY"
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

### Sepolia 部署示例（日志），欢迎使用
```
Script ran successfully.

== Logs ==
  MemeFactory deployed at: 0xE6A24e38E575EdA1DD65Ed3F313035C5C7Da75EF
  Implementation deployed at: 0xC29c43DfD358a6E641F4307797Dff1E0e9F6F4cB
  Project owner: 0x5aba664d6532973C921A6533E20a35438f2E5A40

Chain 11155111 (sepolia)
Tx Hash: 0xa2d0ef7fd43beb53d17a6fc6558ce00a23d5f885147c33b4e73c142dcec1e307
Contract Address: 0xE6A24e38E575EdA1DD65Ed3F313035C5C7Da75EF
Block: 10107661
Paid: 0.00313516129942316 ETH (2971682 gas * 1.05501238 gwei)
```

## 安全要点
- 初始化只允许一次（initializer）
- 仅工厂允许铸造
- 严格供应量限制
- 费用不足直接拒绝

## 许可证
MIT
