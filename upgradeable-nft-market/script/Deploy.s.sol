// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/MarketNFT.sol";
import "../src/PaymentToken.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy NFT implementation and proxy
        MarketNFT nftImpl = new MarketNFT();
        console.log("MarketNFT Implementation deployed at:", address(nftImpl));
        
        bytes memory nftInitData = abi.encodeWithSelector(
            MarketNFT.initialize.selector,
            "Market NFT",
            "MNFT",
            "https://api.example.com/nft/",
            deployer
        );
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftImpl), nftInitData);
        console.log("MarketNFT Proxy deployed at:", address(nftProxy));

        // Deploy Payment Token implementation and proxy
        PaymentToken tokenImpl = new PaymentToken();
        console.log("PaymentToken Implementation deployed at:", address(tokenImpl));
        
        bytes memory tokenInitData = abi.encodeWithSelector(
            PaymentToken.initialize.selector,
            "Payment Token",
            "PAY",
            deployer
        );
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImpl), tokenInitData);
        console.log("PaymentToken Proxy deployed at:", address(tokenProxy));

        // Deploy NFTMarketV1 implementation and proxy
        NFTMarketV1 marketV1Impl = new NFTMarketV1();
        console.log("NFTMarketV1 Implementation deployed at:", address(marketV1Impl));
        
        uint256 feePercent = 250; // 2.5%
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector,
            address(tokenProxy),
            address(nftProxy),
            feePercent,
            deployer
        );
        ERC1967Proxy marketProxy = new ERC1967Proxy(address(marketV1Impl), marketInitData);
        console.log("NFTMarket Proxy deployed at:", address(marketProxy));

        // Deploy NFTMarketV2 implementation (for later upgrade)
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        console.log("NFTMarketV2 Implementation deployed at:", address(marketV2Impl));

        vm.stopBroadcast();

        console.log("\n========================================");
        console.log("         DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("\nProxy Contracts (User-facing):");
        console.log("  MarketNFT Proxy:     ", address(nftProxy));
        console.log("  PaymentToken Proxy:  ", address(tokenProxy));
        console.log("  NFTMarket Proxy:     ", address(marketProxy));
        console.log("\nImplementation Contracts:");
        console.log("  MarketNFT Impl:      ", address(nftImpl));
        console.log("  PaymentToken Impl:   ", address(tokenImpl));
        console.log("  NFTMarketV1 Impl:    ", address(marketV1Impl));
        console.log("  NFTMarketV2 Impl:    ", address(marketV2Impl));
        console.log("========================================\n");
    }
}

contract UpgradeToV2Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketProxy = vm.envAddress("MARKET_PROXY");
        address marketV2Impl = vm.envAddress("MARKET_V2_IMPL");
        
        console.log("Upgrading NFTMarket to V2...");
        console.log("Market Proxy:", marketProxy);
        console.log("New Implementation:", marketV2Impl);
        
        vm.startBroadcast(deployerPrivateKey);

        // Upgrade to V2
        NFTMarketV1(marketProxy).upgradeToAndCall(
            marketV2Impl,
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );

        vm.stopBroadcast();

        // Verify upgrade
        NFTMarketV2 market = NFTMarketV2(marketProxy);
        console.log("\nUpgrade completed!");
        console.log("New version:", market.version());
        console.log("Domain Separator:", vm.toString(market.DOMAIN_SEPARATOR()));
    }
}
