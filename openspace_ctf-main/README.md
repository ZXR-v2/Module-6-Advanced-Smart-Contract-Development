## Try to Hack Vault 

Read the smart contract `Vault.sol`, try to steal all eth from the vault.

You can write a hacker contract and add some code to pass the `forge test` .

### Tips 
you need understand following knowledge points:
1. reentrance 
2. ABI encoding
3. delegatecall


### Anvil

```shell
$ anvil
```

### Deploy

```shell
forge script script/Vault.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## test

```
forge test -vvv
```

## 攻击中心思想

这里的思想不是要获取实际保存在 `VaultLogic` 中的 `password`，而是通过 `delegatecall` 把 `VaultLogic` 的 `changeOwner` 的上下文拉到 `Vault` 的上下文中执行：

1. **存储布局碰撞**：在 `Vault` 合约中，Slot 1 存储的是 `logic` 合约的地址；而在 `VaultLogic` 合约中，Slot 1 存储的是 `password`。
2. **绕过密码校验**：由于 `delegatecall` 使用的是调用方（`Vault`）的存储，`changeOwner(bytes32,address)` 在判别密码时，实际比较的是 `Vault` Slot 1 位置的数据（即 `logic` 合约地址），而不是 `VaultLogic` 原本定义的 `password`。
3. **夺取所有权**：通过传入 `logic` 合约地址作为“密码”，可以顺利通过校验并修改 `Vault` 的 `owner` 为攻击者地址。
4. **资金窃取**：成为 `owner` 后，开启提现开关 (`openWithdraw`)，最后利用 `withdraw` 函数中先转账后销账的漏洞进行**重入攻击**，取走所有资金。
