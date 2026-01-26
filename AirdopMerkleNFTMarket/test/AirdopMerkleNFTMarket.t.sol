// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/PermitToken.sol";
import "../src/MarketNFT.sol";
import "../src/AirdopMerkleNFTMarket.sol";

contract AirdopMerkleNFTMarketTest is Test {
    PermitToken public token;
    MarketNFT public nft;
    AirdopMerkleNFTMarket public market;

    // Test accounts
    address public owner;
    uint256 public ownerPk;
    address public seller;
    uint256 public sellerPk;
    address public buyer;
    uint256 public buyerPk;
    address public whitelistedUser;
    uint256 public whitelistedUserPk;
    address public nonWhitelistedUser;
    uint256 public nonWhitelistedUserPk;

    // Merkle tree data (for 3 whitelisted addresses)
    bytes32 public merkleRoot;
    bytes32[] public whitelistProof;

    // Constants
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 constant NFT_PRICE = 100 ether;
    uint256 constant DISCOUNTED_PRICE = 50 ether; // 50% off

    function setUp() public {
        // Generate test accounts with known private keys
        (owner, ownerPk) = makeAddrAndKey("owner");
        (seller, sellerPk) = makeAddrAndKey("seller");
        (buyer, buyerPk) = makeAddrAndKey("buyer");
        (whitelistedUser, whitelistedUserPk) = makeAddrAndKey("whitelistedUser");
        (nonWhitelistedUser, nonWhitelistedUserPk) = makeAddrAndKey("nonWhitelistedUser");

        vm.startPrank(owner);

        // Deploy Token
        token = new PermitToken("Market Token", "MTK", INITIAL_SUPPLY);

        // Deploy NFT
        nft = new MarketNFT("Market NFT", "MNFT", "https://example.com/nft/");

        // Build Merkle tree for whitelist
        // Whitelist: whitelistedUser, buyer (for testing purposes)
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(whitelistedUser))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(buyer))));
        
        // For a simple 2-leaf tree:
        // If leaf1 < leaf2, root = hash(leaf1, leaf2)
        // Otherwise, root = hash(leaf2, leaf1)
        if (uint256(leaf1) < uint256(leaf2)) {
            merkleRoot = keccak256(abi.encodePacked(leaf1, leaf2));
        } else {
            merkleRoot = keccak256(abi.encodePacked(leaf2, leaf1));
        }

        // Deploy Market
        market = new AirdopMerkleNFTMarket(
            address(token),
            address(nft),
            merkleRoot
        );

        // Distribute tokens
        token.transfer(buyer, 1000 ether);
        token.transfer(whitelistedUser, 1000 ether);
        token.transfer(nonWhitelistedUser, 1000 ether);

        // Mint NFT to seller
        nft.mint(seller);  // tokenId = 0
        nft.mint(seller);  // tokenId = 1
        nft.mint(seller);  // tokenId = 2

        vm.stopPrank();

        // Seller approves market
        vm.startPrank(seller);
        nft.setApprovalForAll(address(market), true);
        vm.stopPrank();
    }

    // ============ Helper Functions ============

    function _getMerkleProof(address account) internal view returns (bytes32[] memory) {
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(whitelistedUser))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(buyer))));
        bytes32 accountLeaf = keccak256(bytes.concat(keccak256(abi.encode(account))));

        bytes32[] memory proof = new bytes32[](1);
        
        if (accountLeaf == leaf1) {
            proof[0] = leaf2;
        } else if (accountLeaf == leaf2) {
            proof[0] = leaf1;
        } else {
            // Not in whitelist, return empty proof
            return new bytes32[](0);
        }
        
        return proof;
    }

    function _getPermitSignature(
        address signer,
        uint256 signerPk,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        
        uint256 nonce = token.nonces(signer);
        
        bytes32 structHash = keccak256(
            abi.encode(permitTypehash, signer, spender, value, nonce, deadline)
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        (v, r, s) = vm.sign(signerPk, digest);
    }

    // ============ Listing Tests ============

    function test_ListNFT() public {
        vm.prank(seller);
        market.list(0, NFT_PRICE);

        (address listedSeller, uint256 price, bool isActive) = market.getListing(0);
        assertEq(listedSeller, seller);
        assertEq(price, NFT_PRICE);
        assertTrue(isActive);
        assertEq(nft.ownerOf(0), address(market));
    }

    function test_DelistNFT() public {
        vm.startPrank(seller);
        market.list(0, NFT_PRICE);
        market.delist(0);
        vm.stopPrank();

        (, , bool isActive) = market.getListing(0);
        assertFalse(isActive);
        assertEq(nft.ownerOf(0), seller);
    }

    function test_RevertWhen_ListWithZeroPrice() public {
        vm.prank(seller);
        vm.expectRevert(AirdopMerkleNFTMarket.InvalidPrice.selector);
        market.list(0, 0);
    }

    function test_RevertWhen_DelistByNonSeller() public {
        vm.prank(seller);
        market.list(0, NFT_PRICE);

        vm.prank(buyer);
        vm.expectRevert(AirdopMerkleNFTMarket.NotSeller.selector);
        market.delist(0);
    }

    // ============ Regular Purchase Tests ============

    function test_BuyNFT() public {
        // List NFT
        vm.prank(seller);
        market.list(0, NFT_PRICE);

        // Approve and buy
        vm.startPrank(buyer);
        token.approve(address(market), NFT_PRICE);
        market.buy(0);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), NFT_PRICE);
    }

    function test_RevertWhen_BuyUnlistedNFT() public {
        vm.prank(buyer);
        vm.expectRevert(AirdopMerkleNFTMarket.NFTNotListed.selector);
        market.buy(0);
    }

    // ============ Whitelist Verification Tests ============

    function test_VerifyWhitelist() public view {
        bytes32[] memory proof = _getMerkleProof(whitelistedUser);
        assertTrue(market.verifyWhitelist(whitelistedUser, proof));
    }

    function test_VerifyWhitelist_InvalidProof() public view {
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(0);
        assertFalse(market.verifyWhitelist(nonWhitelistedUser, invalidProof));
    }

    // ============ Discounted Purchase with Permit Tests ============

    function test_ClaimNFTWithDiscount() public {
        // List NFT
        vm.prank(seller);
        market.list(0, NFT_PRICE);

        // Get permit signature
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            whitelistedUser,
            whitelistedUserPk,
            address(market),
            DISCOUNTED_PRICE,
            deadline
        );

        // Get merkle proof
        bytes32[] memory proof = _getMerkleProof(whitelistedUser);

        // Prepare multicall data
        bytes[] memory calls = new bytes[](2);
        
        // First call: permitPrePay
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            whitelistedUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );
        
        // Second call: claimNFT
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            0,  // tokenId
            proof
        );

        // Execute multicall
        vm.prank(whitelistedUser);
        market.multicall(calls);

        // Verify results
        assertEq(nft.ownerOf(0), whitelistedUser);
        assertEq(token.balanceOf(seller), DISCOUNTED_PRICE);
        assertEq(token.balanceOf(whitelistedUser), 1000 ether - DISCOUNTED_PRICE);
    }

    function test_GetDiscountedPrice() public {
        vm.prank(seller);
        market.list(0, NFT_PRICE);

        uint256 discountedPrice = market.getDiscountedPrice(0);
        assertEq(discountedPrice, DISCOUNTED_PRICE);
    }

    function test_RevertWhen_ClaimWithInvalidProof() public {
        // List NFT
        vm.prank(seller);
        market.list(0, NFT_PRICE);

        // Get permit signature for non-whitelisted user
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            nonWhitelistedUser,
            nonWhitelistedUserPk,
            address(market),
            DISCOUNTED_PRICE,
            deadline
        );

        // Invalid proof
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(0);

        // Prepare multicall data
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            nonWhitelistedUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            0,
            invalidProof
        );

        // Execute multicall - should revert
        vm.prank(nonWhitelistedUser);
        vm.expectRevert(AirdopMerkleNFTMarket.InvalidMerkleProof.selector);
        market.multicall(calls);
    }

    function test_RevertWhen_DoubleClaim() public {
        // List two NFTs
        vm.startPrank(seller);
        market.list(0, NFT_PRICE);
        market.list(1, NFT_PRICE);
        vm.stopPrank();

        // First claim
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            whitelistedUser,
            whitelistedUserPk,
            address(market),
            DISCOUNTED_PRICE,
            deadline
        );

        bytes32[] memory proof = _getMerkleProof(whitelistedUser);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            whitelistedUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            0,
            proof
        );

        vm.prank(whitelistedUser);
        market.multicall(calls);

        // Try to claim the same NFT again (should fail)
        // First need a new permit signature (nonce increased)
        (v, r, s) = _getPermitSignature(
            whitelistedUser,
            whitelistedUserPk,
            address(market),
            DISCOUNTED_PRICE,
            deadline
        );

        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            whitelistedUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            0,  // Same tokenId
            proof
        );

        vm.prank(whitelistedUser);
        vm.expectRevert(AirdopMerkleNFTMarket.NFTNotListed.selector);  // NFT already sold
        market.multicall(calls);
    }

    function test_WhitelistedUserCanClaimMultipleDifferentNFTs() public {
        // List two NFTs
        vm.startPrank(seller);
        market.list(0, NFT_PRICE);
        market.list(1, NFT_PRICE);
        vm.stopPrank();

        bytes32[] memory proof = _getMerkleProof(whitelistedUser);

        // Claim first NFT
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            whitelistedUser,
            whitelistedUserPk,
            address(market),
            DISCOUNTED_PRICE,
            deadline
        );

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            whitelistedUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            0,
            proof
        );

        vm.prank(whitelistedUser);
        market.multicall(calls);

        // Claim second NFT with new permit
        (v, r, s) = _getPermitSignature(
            whitelistedUser,
            whitelistedUserPk,
            address(market),
            DISCOUNTED_PRICE,
            deadline
        );

        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            whitelistedUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            1,  // Different tokenId
            proof
        );

        vm.prank(whitelistedUser);
        market.multicall(calls);

        // Verify both NFTs are owned by whitelistedUser
        assertEq(nft.ownerOf(0), whitelistedUser);
        assertEq(nft.ownerOf(1), whitelistedUser);
    }

    // ============ Admin Tests ============

    function test_SetMerkleRoot() public {
        bytes32 newRoot = keccak256("new root");
        
        vm.prank(owner);
        market.setMerkleRoot(newRoot);

        assertEq(market.merkleRoot(), newRoot);
    }

    function test_RevertWhen_NonOwnerSetsMerkleRoot() public {
        bytes32 newRoot = keccak256("new root");
        
        vm.prank(buyer);
        vm.expectRevert(AirdopMerkleNFTMarket.NotOwner.selector);
        market.setMerkleRoot(newRoot);
    }

    function test_TransferOwnership() public {
        vm.prank(owner);
        market.transferOwnership(buyer);

        assertEq(market.owner(), buyer);
    }

    // ============ Multicall Integration Test ============

    function test_MulticallWithDifferentBuyer() public {
        // List NFT
        vm.prank(seller);
        market.list(0, NFT_PRICE);

        // Buyer is also in whitelist (see setUp)
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            buyer,
            buyerPk,
            address(market),
            DISCOUNTED_PRICE,
            deadline
        );

        bytes32[] memory proof = _getMerkleProof(buyer);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            buyer,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            0,
            proof
        );

        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        uint256 sellerBalanceBefore = token.balanceOf(seller);

        vm.prank(buyer);
        market.multicall(calls);

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - DISCOUNTED_PRICE);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + DISCOUNTED_PRICE);
    }
}
