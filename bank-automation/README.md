# Bank Automation with Chainlink

这是一个使用 Chainlink Automation 实现自动化的 Bank 合约示例。

## 部署信息 (Sepolia)

- **合约地址**: `0x48304A86420293319D7b84C5AeD3dd5DCd94a25A`
- **区块浏览器**: [Etherscan 链接](https://sepolia.etherscan.io/address/0x48304a86420293319d7b84c5aed3dd5dcd94a25a)
- **部署交易哈希**: `0xe07443aa736ab510f28681d75a27fd091e720ec0778aae8ebb3988c33871f943`
- **状态**: 已成功验证 (Pass - Verified)

## 功能描述

1.  用户通过 `deposit()` 存款。
2.  合约记录余额并触发 `Deposited` 事件。
3.  当合约中的总余额超过设定的阈值（`threshold`）时，Chainlink Automation 会自动触发 `performUpkeep`。
4.  `performUpkeep` 会将合约余额的一半转移给 `owner`。

## 如何运行

### 1. 配置环境

在项目根目录下新建 `.env` 文件，并填入以下内容：

```env
PRIVATE_KEY=您的私钥
SEPOLIA_RPC_URL=您的 Sepolia RPC URL
ETHERSCAN_API_KEY=您的 Etherscan API KEY (用于验证合约)
```

### 2. 部署合约到 Sepolia

运行以下命令进行部署：

```bash
forge script script/Deploy.s.sol:DeployBank --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

部署完成后，记录下合约地址。

### 3. 在 Chainlink Automation 上注册任务

1.  访问 [Chainlink Automation App](https://automation.chain.link/)。
2.  连接你的钱包（切换到 Sepolia 网络）。
3.  点击 **"Register new Upkeep"**。
4.  选择 **"Custom logic"**。
5.  输入刚才部署的 **Bank 合约地址**。
6.  设置任务名称和联系邮箱。
7.  **Gas limit**: 建议设置为 200,000 或更高。
8.  **Starting balance**: 存入一些 LINK 代币作为支付费用（Sepolia 测试网可以在 [faucets.chain.link](https://faucets.chain.link/) 获取测试 LINK）。
9.  点击 **"Register Upkeep"** 并确认交易。

### 4. 测试自动化任务

1.  向合约存款：调用 `deposit()` 存入超过阈值（默认 0.01 ETH）的金额。
2.  等待几分钟，Chainlink 节点会检测到 `checkUpkeep` 返回 true。
3.  任务会自动触发 `performUpkeep`，你会看到合约余额减少，且 Owner 收到资金。
4.  你可以在 Chainlink 控制面板看到执行记录。

## 代码链接

- [GitHub 仓库](https://github.com/your-username/bank-automation) (请将代码上传后替换此链接)
- [Etherscan 已验证代码](https://sepolia.etherscan.io/address/0x48304a86420293319d7b84c5aed3dd5dcd94a25a#code)
- [Chainlink Automation 执行记录](https://automation.chain.link/sepolia/81505629592459099950703531743198166546776416527697562837201995252543055929952) (注册后可在此处查看)
