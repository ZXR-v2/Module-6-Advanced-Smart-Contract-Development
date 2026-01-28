// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/MarketNFT.sol";
import "../src/PaymentToken.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTMarketTest is Test {
    // Contracts
    MarketNFT public nftImpl;
    MarketNFT public nft;
    PaymentToken public tokenImpl;
    PaymentToken public token;
    NFTMarketV1 public marketV1Impl;
    NFTMarketV2 public marketV2Impl;
    NFTMarketV1 public market;
    
    // Proxies
    ERC1967Proxy public nftProxy;
    ERC1967Proxy public tokenProxy;
    ERC1967Proxy public marketProxy;

    // Test accounts
    address public owner;
    uint256 public ownerPrivateKey;
    address public seller;
    uint256 public sellerPrivateKey;
    address public buyer;
    uint256 public buyerPrivateKey;

    // Constants
    uint256 constant INITIAL_BALANCE = 10000 ether;
    uint256 constant FEE_PERCENT = 250; // 2.5%
    uint256 constant NFT_PRICE = 100 ether;

    function setUp() public {
        // Setup test accounts with private keys for signing
        ownerPrivateKey = 0x1;
        owner = vm.addr(ownerPrivateKey);
        
        sellerPrivateKey = 0x2;
        seller = vm.addr(sellerPrivateKey);
        
        buyerPrivateKey = 0x3;
        buyer = vm.addr(buyerPrivateKey);

        vm.startPrank(owner);

        // Deploy NFT implementation and proxy
        nftImpl = new MarketNFT();
        bytes memory nftInitData = abi.encodeWithSelector(
            MarketNFT.initialize.selector,
            "Market NFT",
            "MNFT",
            "https://api.example.com/nft/",
            owner
        );
        nftProxy = new ERC1967Proxy(address(nftImpl), nftInitData);
        nft = MarketNFT(address(nftProxy));

        // Deploy Payment Token implementation and proxy
        tokenImpl = new PaymentToken();
        bytes memory tokenInitData = abi.encodeWithSelector(
            PaymentToken.initialize.selector,
            "Payment Token",
            "PAY",
            owner
        );
        tokenProxy = new ERC1967Proxy(address(tokenImpl), tokenInitData);
        token = PaymentToken(address(tokenProxy));

        // Deploy NFTMarketV1 implementation and proxy
        marketV1Impl = new NFTMarketV1();
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector,
            address(token),
            address(nft),
            FEE_PERCENT,
            owner
        );
        marketProxy = new ERC1967Proxy(address(marketV1Impl), marketInitData);
        market = NFTMarketV1(address(marketProxy));

        // Deploy NFTMarketV2 implementation (not yet upgraded)
        marketV2Impl = new NFTMarketV2();

        // Mint tokens to buyer
        token.mint(buyer, INITIAL_BALANCE);

        // Mint NFTs to seller
        nft.mint(seller);
        nft.mint(seller);
        nft.mint(seller);

        vm.stopPrank();

        // Approve marketplace to spend buyer's tokens
        vm.prank(buyer);
        token.approve(address(market), type(uint256).max);

        // Approve marketplace for seller's NFTs
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
    }

    // ============ V1 Basic Functionality Tests ============

    function test_V1_Version() public view {
        assertEq(market.version(), "1.0.0");
    }

    function test_V1_List() public {
        vm.prank(seller);
        market.list(1, NFT_PRICE);
        
        (address listedSeller, uint256 price, bool isActive) = market.getListing(1);
        assertEq(listedSeller, seller);
        assertEq(price, NFT_PRICE);
        assertTrue(isActive);
        assertEq(market.totalListings(), 1);
        
        // NFT should be in escrow
        assertEq(nft.ownerOf(1), address(market));
    }

    function test_V1_Delist() public {
        vm.startPrank(seller);
        market.list(1, NFT_PRICE);
        market.delist(1);
        vm.stopPrank();
        
        (, , bool isActive) = market.getListing(1);
        assertFalse(isActive);
        assertEq(market.totalListings(), 0);
        
        // NFT should be returned to seller
        assertEq(nft.ownerOf(1), seller);
    }

    function test_V1_Buy() public {
        vm.prank(seller);
        market.list(1, NFT_PRICE);
        
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        
        vm.prank(buyer);
        market.buy(1);
        
        // Calculate expected amounts
        uint256 fee = (NFT_PRICE * FEE_PERCENT) / 10000;
        uint256 sellerAmount = NFT_PRICE - fee;
        
        // Verify balances
        assertEq(token.balanceOf(seller), sellerBalanceBefore + sellerAmount);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);
        assertEq(market.accumulatedFees(), fee);
        
        // Verify NFT ownership
        assertEq(nft.ownerOf(1), buyer);
        
        // Verify listing is inactive
        (, , bool isActive) = market.getListing(1);
        assertFalse(isActive);
    }

    function test_V1_WithdrawFees() public {
        // Create a sale to accumulate fees
        vm.prank(seller);
        market.list(1, NFT_PRICE);
        
        vm.prank(buyer);
        market.buy(1);
        
        uint256 expectedFee = (NFT_PRICE * FEE_PERCENT) / 10000;
        assertEq(market.accumulatedFees(), expectedFee);
        
        // Withdraw fees
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        
        vm.prank(owner);
        market.withdrawFees(owner);
        
        assertEq(token.balanceOf(owner), ownerBalanceBefore + expectedFee);
        assertEq(market.accumulatedFees(), 0);
    }

    // ============ Upgrade Tests ============

    function test_UpgradeToV2() public {
        // First, create some state in V1
        vm.prank(seller);
        market.list(1, NFT_PRICE);
        
        // Record state before upgrade
        (address sellerBefore, uint256 priceBefore, bool isActiveBefore) = market.getListing(1);
        uint256 totalListingsBefore = market.totalListings();
        uint256 feePercentBefore = market.feePercent();
        
        // Upgrade to V2
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        // Cast to V2
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        
        // Verify version changed
        assertEq(marketV2.version(), "2.0.0");
        
        // Verify state is preserved
        (address sellerAfter, uint256 priceAfter, bool isActiveAfter) = marketV2.getListing(1);
        assertEq(sellerAfter, sellerBefore, "Seller should be preserved");
        assertEq(priceAfter, priceBefore, "Price should be preserved");
        assertEq(isActiveAfter, isActiveBefore, "IsActive should be preserved");
        assertEq(marketV2.totalListings(), totalListingsBefore, "Total listings should be preserved");
        assertEq(marketV2.feePercent(), feePercentBefore, "Fee percent should be preserved");
        
        console.log("=== Upgrade Test Results ===");
        console.log("Version before: 1.0.0");
        console.log("Version after:", marketV2.version());
        console.log("Seller preserved:", sellerAfter == sellerBefore);
        console.log("Price preserved:", priceAfter == priceBefore);
        console.log("Total listings preserved:", marketV2.totalListings() == totalListingsBefore);
    }

    function test_UpgradePreservesMultipleListings() public {
        // Create multiple listings in V1
        vm.startPrank(seller);
        market.list(1, NFT_PRICE);
        market.list(2, NFT_PRICE * 2);
        vm.stopPrank();
        
        // Buy one NFT
        vm.prank(buyer);
        market.buy(1);
        
        // Record state
        uint256 accumulatedFeesBefore = market.accumulatedFees();
        (address seller2Before, uint256 price2Before, bool isActive2Before) = market.getListing(2);
        
        // Upgrade to V2
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        
        // Verify all state preserved
        assertEq(marketV2.accumulatedFees(), accumulatedFeesBefore);
        (address seller2After, uint256 price2After, bool isActive2After) = marketV2.getListing(2);
        assertEq(seller2After, seller2Before);
        assertEq(price2After, price2Before);
        assertEq(isActive2After, isActive2Before);
        
        // Verify listing 1 is no longer active
        (, , bool isActive1) = marketV2.getListing(1);
        assertFalse(isActive1);
        
        console.log("=== Multiple Listings Upgrade Test ===");
        console.log("Accumulated fees preserved:", marketV2.accumulatedFees() == accumulatedFeesBefore);
        console.log("Listing 2 seller preserved:", seller2After == seller2Before);
        console.log("Listing 2 price preserved:", price2After == price2Before);
        console.log("Listing 2 active status preserved:", isActive2After == isActive2Before);
    }

    function test_V1FunctionalityWorksAfterUpgrade() public {
        // Upgrade first
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        
        // V1 functionality should still work
        vm.prank(seller);
        marketV2.list(1, NFT_PRICE);
        
        (address listedSeller, uint256 price, bool isActive) = marketV2.getListing(1);
        assertEq(listedSeller, seller);
        assertEq(price, NFT_PRICE);
        assertTrue(isActive);
        
        // Buy should work
        vm.prank(buyer);
        marketV2.buy(1);
        
        assertEq(nft.ownerOf(1), buyer);
        
        console.log("=== V1 Functionality After Upgrade ===");
        console.log("List works: true");
        console.log("Buy works: true");
        console.log("NFT transferred to buyer: true");
    }

    // ============ V2 Signature-Based Listing Tests ============

    function test_V2_ListWithSignature() public {
        // Upgrade to V2
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        
        // Create signature for listing
        uint256 tokenId = 1;
        uint256 price = NFT_PRICE;
        uint256 nonce = marketV2.getNonce(seller);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = marketV2.getListingDigest(tokenId, price, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        
        // Anyone can submit the listing with signature
        vm.prank(buyer);
        marketV2.listWithSignature(tokenId, price, deadline, v, r, s);
        
        // Verify listing
        (address listedSeller, uint256 listedPrice, bool isActive) = marketV2.getListing(tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(isActive);
        
        // NFT should be in escrow
        assertEq(nft.ownerOf(tokenId), address(marketV2));
        
        console.log("=== V2 Signature Listing Test ===");
        console.log("Token ID:", tokenId);
        console.log("Price:", price);
        console.log("Seller:", seller);
        console.log("NFT in escrow:", nft.ownerOf(tokenId) == address(marketV2));
    }

    function test_V2_BuyWithSignature() public {
        // Upgrade to V2
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        
        // Create signature for direct buy
        uint256 tokenId = 1;
        uint256 price = NFT_PRICE;
        uint256 nonce = marketV2.getNonce(seller);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = marketV2.getListingDigest(tokenId, price, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        
        // Buy directly with signature (no listing transaction needed)
        vm.prank(buyer);
        marketV2.buyWithSignature(tokenId, price, deadline, v, r, s);
        
        // Calculate expected amounts
        uint256 fee = (price * FEE_PERCENT) / 10000;
        uint256 sellerAmount = price - fee;
        
        // Verify balances
        assertEq(token.balanceOf(seller), sellerBalanceBefore + sellerAmount);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - price);
        assertEq(marketV2.accumulatedFees(), fee);
        
        // Verify NFT ownership
        assertEq(nft.ownerOf(tokenId), buyer);
        
        console.log("=== V2 Buy With Signature Test ===");
        console.log("Direct purchase completed");
        console.log("Seller received:", sellerAmount);
        console.log("Fee collected:", fee);
        console.log("NFT transferred to buyer:", nft.ownerOf(tokenId) == buyer);
    }

    function test_V2_SignatureReplayProtection() public {
        // Upgrade to V2
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        
        // Create and use a signature
        uint256 tokenId = 1;
        uint256 price = NFT_PRICE;
        uint256 nonce = marketV2.getNonce(seller);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = marketV2.getListingDigest(tokenId, price, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        
        // First use should succeed
        vm.prank(buyer);
        marketV2.listWithSignature(tokenId, price, deadline, v, r, s);
        
        // Delist to free the NFT
        vm.prank(seller);
        marketV2.delist(tokenId);
        
        // Second use with same signature should fail
        vm.expectRevert(NFTMarketV2.SignatureAlreadyUsed.selector);
        vm.prank(buyer);
        marketV2.listWithSignature(tokenId, price, deadline, v, r, s);
        
        console.log("=== Signature Replay Protection Test ===");
        console.log("First signature use: SUCCESS");
        console.log("Second signature use: REVERTED (SignatureAlreadyUsed)");
    }

    function test_V2_ExpiredSignature() public {
        // Upgrade to V2
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        
        // Create signature with past deadline
        uint256 tokenId = 1;
        uint256 price = NFT_PRICE;
        uint256 nonce = marketV2.getNonce(seller);
        uint256 deadline = block.timestamp - 1; // Past deadline
        
        bytes32 digest = marketV2.getListingDigest(tokenId, price, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        
        // Should revert with expired signature
        vm.expectRevert(NFTMarketV2.SignatureExpired.selector);
        vm.prank(buyer);
        marketV2.listWithSignature(tokenId, price, deadline, v, r, s);
        
        console.log("=== Expired Signature Test ===");
        console.log("Expired signature rejected: true");
    }

    function test_V2_InvalidSignature() public {
        // Upgrade to V2
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        
        // Create signature with wrong signer (buyer instead of seller)
        uint256 tokenId = 1;
        uint256 price = NFT_PRICE;
        uint256 nonce = marketV2.getNonce(seller);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = marketV2.getListingDigest(tokenId, price, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, digest); // Wrong signer!
        
        // Should revert with invalid signature
        vm.expectRevert(NFTMarketV2.InvalidSignature.selector);
        vm.prank(buyer);
        marketV2.listWithSignature(tokenId, price, deadline, v, r, s);
        
        console.log("=== Invalid Signature Test ===");
        console.log("Invalid signature rejected: true");
    }

    function test_V2_CancelAllSignatures() public {
        // Upgrade to V2
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        
        // Create signature
        uint256 tokenId = 1;
        uint256 price = NFT_PRICE;
        uint256 nonce = marketV2.getNonce(seller);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = marketV2.getListingDigest(tokenId, price, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        
        // Cancel all signatures by incrementing nonce
        vm.prank(seller);
        marketV2.cancelAllSignatures();
        
        // Signature should now be invalid
        vm.expectRevert(NFTMarketV2.InvalidSignature.selector);
        vm.prank(buyer);
        marketV2.listWithSignature(tokenId, price, deadline, v, r, s);
        
        console.log("=== Cancel All Signatures Test ===");
        console.log("Nonce incremented, old signature invalidated: true");
    }

    // ============ Complete Flow Test ============

    function test_CompleteUpgradeFlow() public {
        console.log("\n========================================");
        console.log("   COMPLETE UPGRADE FLOW TEST");
        console.log("========================================\n");
        
        // Phase 1: Use V1 functionality
        console.log("--- Phase 1: V1 Functionality ---");
        console.log("Market Version:", market.version());
        
        vm.prank(seller);
        market.list(1, NFT_PRICE);
        console.log("Listed NFT #1 for", NFT_PRICE / 1e18, "tokens");
        
        vm.prank(buyer);
        market.buy(1);
        console.log("Buyer purchased NFT #1");
        console.log("NFT #1 owner:", nft.ownerOf(1));
        
        // Phase 2: Create more listings before upgrade
        console.log("\n--- Phase 2: More Listings Before Upgrade ---");
        vm.prank(seller);
        market.list(2, NFT_PRICE * 2);
        console.log("Listed NFT #2 for", (NFT_PRICE * 2) / 1e18, "tokens");
        
        uint256 feesBeforeUpgrade = market.accumulatedFees();
        console.log("Accumulated fees before upgrade:", feesBeforeUpgrade / 1e18, "tokens");
        
        // Phase 3: Upgrade to V2
        console.log("\n--- Phase 3: Upgrade to V2 ---");
        vm.prank(owner);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));
        console.log("Market Version after upgrade:", marketV2.version());
        
        // Verify state preserved
        uint256 feesAfterUpgrade = marketV2.accumulatedFees();
        console.log("Accumulated fees after upgrade:", feesAfterUpgrade / 1e18, "tokens");
        console.log("Fees preserved:", feesAfterUpgrade == feesBeforeUpgrade);
        
        (address seller2, uint256 price2, bool isActive2) = marketV2.getListing(2);
        console.log("Listing #2 preserved - seller:", seller2);
        console.log("Listing #2 price:", price2 / 1e18, "active:", isActive2);
        
        // Phase 4: Use V2 signature functionality
        console.log("\n--- Phase 4: V2 Signature Functionality ---");
        
        // Mint new NFT to seller for signature test
        vm.prank(owner);
        nft.mint(seller);
        uint256 newTokenId = 4;
        
        // Create signature
        uint256 nonce = marketV2.getNonce(seller);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = marketV2.getListingDigest(newTokenId, NFT_PRICE, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        
        console.log("Created signature for NFT #", newTokenId);
        console.log("Price:", NFT_PRICE / 1e18, "tokens");
        console.log("Deadline:", deadline);
        
        // Buy with signature
        vm.prank(buyer);
        marketV2.buyWithSignature(newTokenId, NFT_PRICE, deadline, v, r, s);
        
        console.log("Purchased NFT #", newTokenId, "with signature");
        console.log("NFT #", newTokenId, "new owner:", nft.ownerOf(newTokenId));
        
        // Phase 5: V1 functionality still works
        console.log("\n--- Phase 5: V1 Functionality Still Works ---");
        
        // Buy NFT #2 using V1 style
        vm.prank(buyer);
        marketV2.buy(2);
        console.log("Purchased NFT #2 using V1 buy function");
        console.log("NFT #2 owner:", nft.ownerOf(2));
        
        // Final state
        console.log("\n--- Final State ---");
        console.log("Total accumulated fees:", marketV2.accumulatedFees() / 1e18, "tokens");
        console.log("Buyer token balance:", token.balanceOf(buyer) / 1e18);
        console.log("Seller token balance:", token.balanceOf(seller) / 1e18);
        
        console.log("\n========================================");
        console.log("   UPGRADE TEST COMPLETED SUCCESSFULLY");
        console.log("========================================\n");
    }
}
