// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MemeFactory.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署工厂合约
        MemeFactory factory = new MemeFactory();
        
        console.log("MemeFactory deployed at:", address(factory));
        console.log("Implementation deployed at:", factory.implementation());
        console.log("Project owner:", factory.projectOwner());
        
        vm.stopBroadcast();
    }
}
