// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Bank.sol";

contract DeployBank is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 设置阈值为 0.01 ETH (Sepolia 测试用)
        uint256 threshold = 0.01 ether;
        Bank bank = new Bank(threshold);

        console.log("Bank deployed to:", address(bank));

        vm.stopBroadcast();
    }
}
