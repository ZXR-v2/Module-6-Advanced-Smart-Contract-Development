// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public projectOwner;
    address public issuer;
    address public minter1;
    address public minter2;
    
    event MemeDeployed(
        address indexed memeToken,
        address indexed issuer,
        string symbol,
        uint256 maxSupply,
        uint256 perMint,
        uint256 price
    );
    
    event MemeMinted(
        address indexed memeToken,
        address indexed minter,
        uint256 amount,
        uint256 cost,
        uint256 projectFee,
        uint256 issuerFee
    );
    
    function setUp() public {
        projectOwner = makeAddr("projectOwner");
        issuer = makeAddr("issuer");
        minter1 = makeAddr("minter1");
        minter2 = makeAddr("minter2");
        
        vm.startPrank(projectOwner);
        factory = new MemeFactory();
        vm.stopPrank();
        
        // 给测试账户一些ETH
        vm.deal(issuer, 100 ether);
        vm.deal(minter1, 100 ether);
        vm.deal(minter2, 100 ether);
    }
    
    function testDeployMeme() public {
        vm.startPrank(issuer);
        
        address memeToken = factory.deployMeme(
            "PEPE",
            1000000 * 1e18,  // 总供应量 100万
            1000 * 1e18,      // 每次铸造 1000个
            0.001 ether       // 每个代币 0.001 ETH
        );
        
        vm.stopPrank();
        
        assertTrue(memeToken != address(0), "Meme token should be created");
        assertTrue(factory.isMeme(memeToken), "Should be registered as meme");
        
        MemeToken meme = MemeToken(memeToken);
        assertEq(meme.symbol(), "PEPE");
        assertEq(meme.maxSupply(), 1000000 * 1e18);
        assertEq(meme.perMint(), 1000 * 1e18);
        assertEq(meme.price(), 0.001 ether);
        assertEq(meme.issuer(), issuer);
        assertEq(meme.factory(), address(factory));
    }
    
    function testMintMeme() public {
        // 1. 发行者创建Meme
        vm.startPrank(issuer);
        address memeToken = factory.deployMeme(
            "DOGE",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        vm.stopPrank();
        
        MemeToken meme = MemeToken(memeToken);
        
        // 2. 铸造者铸造代币
        uint256 costPerMint = (meme.perMint() * meme.price()) / 1e18; // 1000 * 0.001 = 1 ETH
        
        vm.startPrank(minter1);
        factory.mintMeme{value: costPerMint}(memeToken);
        vm.stopPrank();
        
        // 验证代币余额
        assertEq(meme.balanceOf(minter1), 1000 * 1e18, "Minter should receive tokens");
        assertEq(meme.totalSupply(), 1000 * 1e18, "Total supply should increase");
    }
    
    function testFeeDistribution() public {
        // 1. 发行者创建Meme
        vm.startPrank(issuer);
        address memeToken = factory.deployMeme(
            "SHIB",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        vm.stopPrank();
        
        MemeToken meme = MemeToken(memeToken);
        uint256 costPerMint = (meme.perMint() * meme.price()) / 1e18; // 1 ETH
        
        // 记录铸造前的余额
        uint256 projectBalanceBefore = projectOwner.balance;
        uint256 issuerBalanceBefore = issuer.balance;
        
        // 2. 铸造代币
        vm.startPrank(minter1);
        factory.mintMeme{value: costPerMint}(memeToken);
        vm.stopPrank();
        
        // 3. 验证费用分配
        uint256 projectBalanceAfter = projectOwner.balance;
        uint256 issuerBalanceAfter = issuer.balance;
        
        uint256 expectedProjectFee = (costPerMint * 1) / 100; // 1%
        uint256 expectedIssuerFee = costPerMint - expectedProjectFee; // 99%
        
        assertEq(
            projectBalanceAfter - projectBalanceBefore,
            expectedProjectFee,
            "Project should receive 1% fee"
        );
        
        assertEq(
            issuerBalanceAfter - issuerBalanceBefore,
            expectedIssuerFee,
            "Issuer should receive 99% fee"
        );
    }
    
    function testMultipleMints() public {
        // 1. 创建Meme
        vm.startPrank(issuer);
        address memeToken = factory.deployMeme(
            "FLOKI",
            10000 * 1e18,    // 总量 10000
            1000 * 1e18,     // 每次 1000
            0.001 ether
        );
        vm.stopPrank();
        
        MemeToken meme = MemeToken(memeToken);
        uint256 costPerMint = (meme.perMint() * meme.price()) / 1e18;
        
        // 2. 多次铸造
        vm.startPrank(minter1);
        factory.mintMeme{value: costPerMint}(memeToken);
        vm.stopPrank();
        
        vm.startPrank(minter2);
        factory.mintMeme{value: costPerMint}(memeToken);
        vm.stopPrank();
        
        // 3. 验证
        assertEq(meme.balanceOf(minter1), 1000 * 1e18);
        assertEq(meme.balanceOf(minter2), 1000 * 1e18);
        assertEq(meme.totalSupply(), 2000 * 1e18);
    }
    
    function testCannotExceedMaxSupply() public {
        // 1. 创建小供应量的Meme
        vm.startPrank(issuer);
        address memeToken = factory.deployMeme(
            "TINY",
            2000 * 1e18,     // 总量只有 2000
            1000 * 1e18,     // 每次 1000
            0.001 ether
        );
        vm.stopPrank();
        
        MemeToken meme = MemeToken(memeToken);
        uint256 costPerMint = (meme.perMint() * meme.price()) / 1e18;
        
        // 2. 第一次铸造成功
        vm.startPrank(minter1);
        factory.mintMeme{value: costPerMint}(memeToken);
        vm.stopPrank();
        
        // 3. 第二次铸造成功
        vm.startPrank(minter2);
        factory.mintMeme{value: costPerMint}(memeToken);
        vm.stopPrank();
        
        // 4. 第三次铸造应该失败（超过总供应量）
        vm.startPrank(minter1);
        vm.expectRevert("Exceeds max supply");
        factory.mintMeme{value: costPerMint}(memeToken);
        vm.stopPrank();
        
        // 验证总供应量没有超过
        assertEq(meme.totalSupply(), 2000 * 1e18);
    }
    
    function testInsufficientPayment() public {
        vm.startPrank(issuer);
        address memeToken = factory.deployMeme(
            "EXPENSIVE",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        vm.stopPrank();
        
        MemeToken meme = MemeToken(memeToken);
        uint256 costPerMint = (meme.perMint() * meme.price()) / 1e18;
        
        // 尝试用不足的金额铸造
        vm.startPrank(minter1);
        vm.expectRevert("Insufficient payment");
        factory.mintMeme{value: costPerMint - 1}(memeToken);
        vm.stopPrank();
    }
    
    function testRefundExcessPayment() public {
        vm.startPrank(issuer);
        address memeToken = factory.deployMeme(
            "REFUND",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        vm.stopPrank();
        
        MemeToken meme = MemeToken(memeToken);
        uint256 costPerMint = (meme.perMint() * meme.price()) / 1e18;
        uint256 excessPayment = 2 ether;
        
        uint256 balanceBefore = minter1.balance;
        
        vm.startPrank(minter1);
        factory.mintMeme{value: costPerMint + excessPayment}(memeToken);
        vm.stopPrank();
        
        uint256 balanceAfter = minter1.balance;
        
        // 应该只花费 costPerMint，多余的被退回
        assertEq(
            balanceBefore - balanceAfter,
            costPerMint,
            "Should only charge exact cost"
        );
    }
    
    function testERC20Transfer() public {
        // 创建并铸造
        vm.startPrank(issuer);
        address memeToken = factory.deployMeme(
            "TRANSFER",
            1000000 * 1e18,
            1000 * 1e18,
            0.001 ether
        );
        vm.stopPrank();
        
        MemeToken meme = MemeToken(memeToken);
        uint256 costPerMint = (meme.perMint() * meme.price()) / 1e18;
        
        vm.startPrank(minter1);
        factory.mintMeme{value: costPerMint}(memeToken);
        
        // 转账
        uint256 transferAmount = 100 * 1e18;
        meme.transfer(minter2, transferAmount);
        vm.stopPrank();
        
        assertEq(meme.balanceOf(minter1), 900 * 1e18);
        assertEq(meme.balanceOf(minter2), 100 * 1e18);
    }
    
    function testMultipleMemesDeployed() public {
        vm.startPrank(issuer);
        
        address meme1 = factory.deployMeme("MEME1", 1000000 * 1e18, 1000 * 1e18, 0.001 ether);
        address meme2 = factory.deployMeme("MEME2", 2000000 * 1e18, 2000 * 1e18, 0.002 ether);
        address meme3 = factory.deployMeme("MEME3", 3000000 * 1e18, 3000 * 1e18, 0.003 ether);
        
        vm.stopPrank();
        
        assertEq(factory.getMemeCount(), 3);
        assertEq(factory.getMeme(0), meme1);
        assertEq(factory.getMeme(1), meme2);
        assertEq(factory.getMeme(2), meme3);
    }
}
