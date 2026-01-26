// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/PermitToken.sol";
import "../src/MarketNFT.sol";
import "../src/AirdopMerkleNFTMarket.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        bytes32 merkleRoot = vm.envBytes32("MERKLE_ROOT");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Token
        PermitToken token = new PermitToken(
            "Airdrop Market Token",
            "AMT",
            1_000_000 ether
        );
        console.log("PermitToken deployed at:", address(token));

        // Deploy NFT
        MarketNFT nft = new MarketNFT(
            "Airdrop Market NFT",
            "AMNFT",
            "https://api.example.com/nft/"
        );
        console.log("MarketNFT deployed at:", address(nft));

        // Deploy Market
        AirdopMerkleNFTMarket market = new AirdopMerkleNFTMarket(
            address(token),
            address(nft),
            merkleRoot
        );
        console.log("AirdopMerkleNFTMarket deployed at:", address(market));

        vm.stopBroadcast();
    }
}
