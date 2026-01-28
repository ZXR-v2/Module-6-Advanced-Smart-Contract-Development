// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/MarketNFT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title SupportsInterfaceDemo
 * @notice Demo of supportsInterface function
 */
contract SupportsInterfaceDemo is Test {
    MarketNFT public nft;
    
    function setUp() public {
        // Deploy NFT contract
        MarketNFT nftImpl = new MarketNFT();
        bytes memory initData = abi.encodeWithSelector(
            MarketNFT.initialize.selector,
            "Demo NFT",
            "DEMO",
            "https://example.com/",
            address(this)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(nftImpl), initData);
        nft = MarketNFT(address(proxy));
    }

    function test_SupportsInterfaceDemo() public view {
        console.log("\n============================================");
        console.log("   supportsInterface() Function Demo");
        console.log("============================================\n");
        
        // ============================================================
        // 1. Check ERC165 interface support
        // ============================================================
        bytes4 ERC165_ID = type(IERC165).interfaceId;
        bool supportsERC165 = nft.supportsInterface(ERC165_ID);
        
        console.log("1. ERC165 (Interface Detection Standard)");
        console.log("   interfaceId:", vm.toString(ERC165_ID));
        console.log("   supported:", supportsERC165);
        console.log("");
        
        // ============================================================
        // 2. Check ERC721 interface support
        // ============================================================
        bytes4 ERC721_ID = type(IERC721).interfaceId;
        bool supportsERC721 = nft.supportsInterface(ERC721_ID);
        
        console.log("2. ERC721 (NFT Base Standard)");
        console.log("   interfaceId:", vm.toString(ERC721_ID));
        console.log("   supported:", supportsERC721);
        console.log("   functions: balanceOf, ownerOf, transferFrom, approve...");
        console.log("");
        
        // ============================================================
        // 3. Check ERC721Metadata interface support
        // ============================================================
        bytes4 ERC721Metadata_ID = type(IERC721Metadata).interfaceId;
        bool supportsMetadata = nft.supportsInterface(ERC721Metadata_ID);
        
        console.log("3. ERC721Metadata (Metadata Extension)");
        console.log("   interfaceId:", vm.toString(ERC721Metadata_ID));
        console.log("   supported:", supportsMetadata);
        console.log("   functions: name(), symbol(), tokenURI()");
        console.log("");
        
        // ============================================================
        // 4. Check ERC721Enumerable interface support
        // ============================================================
        bytes4 ERC721Enumerable_ID = type(IERC721Enumerable).interfaceId;
        bool supportsEnumerable = nft.supportsInterface(ERC721Enumerable_ID);
        
        console.log("4. ERC721Enumerable (Enumeration Extension)");
        console.log("   interfaceId:", vm.toString(ERC721Enumerable_ID));
        console.log("   supported:", supportsEnumerable);
        console.log("   functions: totalSupply(), tokenByIndex(), tokenOfOwnerByIndex()");
        console.log("");
        
        // ============================================================
        // 5. Check unsupported interface
        // ============================================================
        bytes4 RANDOM_ID = 0x12345678;
        bool supportsRandom = nft.supportsInterface(RANDOM_ID);
        
        console.log("5. Random Interface (does not exist)");
        console.log("   interfaceId:", vm.toString(RANDOM_ID));
        console.log("   supported:", supportsRandom);
        console.log("");
        
        // ============================================================
        // 6. How interfaceId is calculated
        // ============================================================
        console.log("============================================");
        console.log("   How interfaceId is Calculated");
        console.log("============================================\n");
        
        bytes4 balanceOfSelector = bytes4(keccak256("balanceOf(address)"));
        bytes4 ownerOfSelector = bytes4(keccak256("ownerOf(uint256)"));
        
        console.log("Function selector calculation:");
        console.log("  balanceOf(address)  =", vm.toString(balanceOfSelector));
        console.log("  ownerOf(uint256)    =", vm.toString(ownerOfSelector));
        console.log("");
        console.log("interfaceId = XOR of all function selectors");
        console.log("ERC165 has only one function:");
        console.log("  supportsInterface(bytes4) =", vm.toString(bytes4(keccak256("supportsInterface(bytes4)"))));
        console.log("  So ERC165 interfaceId     =", vm.toString(ERC165_ID));
        
        console.log("\n============================================");
        console.log("   Real-World Use Case");
        console.log("============================================\n");
        
        console.log("A marketplace might check before listing:");
        console.log("");
        console.log("  function listNFT(address nftContract, uint256 tokenId) {");
        console.log("      require(");
        console.log("          IERC165(nftContract).supportsInterface(0x80ac58cd),");
        console.log("          'Not an ERC721'");
        console.log("      );");
        console.log("      // ... continue processing");
        console.log("  }");
        
        console.log("\n============================================\n");
        
        // Verify all assertions
        assertTrue(supportsERC165, "Should support ERC165");
        assertTrue(supportsERC721, "Should support ERC721");
        assertTrue(supportsMetadata, "Should support ERC721Metadata");
        assertTrue(supportsEnumerable, "Should support ERC721Enumerable");
        assertFalse(supportsRandom, "Should not support random interface");
    }
}
