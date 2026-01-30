// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyTokenV2.sol";
import "../src/TokenBankV2.sol";

/**
 * @title DeployLocal
 * @dev 本地测试部署脚本，使用Anvil默认账户
 */
contract DeployLocal is Script {
    // Anvil 默认账户 #0 的私钥
    uint256 constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external {
        // 开始广播交易
        vm.startBroadcast(ANVIL_PRIVATE_KEY);

        // 部署 MyTokenV2，初始供应量为 1,000,000 MTK
        MyTokenV2 tokenV2 = new MyTokenV2(1000000);
        console.log("MyTokenV2 deployed at:", address(tokenV2));

        // 部署 TokenBankV2
        TokenBankV2 bankV2 = new TokenBankV2(address(tokenV2));
        console.log("TokenBankV2 deployed at:", address(bankV2));

        vm.stopBroadcast();

        // 输出部署信息
        console.log("\n=== Local Deployment Summary ===");
        console.log("MyTokenV2:", address(tokenV2));
        console.log("TokenBankV2:", address(bankV2));
        console.log("Deployer:", vm.addr(ANVIL_PRIVATE_KEY));
    }
}
