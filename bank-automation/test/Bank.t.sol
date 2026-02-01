// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address public owner = address(1);
    address public user = address(2);
    uint256 public threshold = 1 ether;

    function setUp() public {
        vm.prank(owner);
        bank = new Bank(threshold);
    }

    function testDeposit() public {
        vm.deal(user, 2 ether);
        vm.prank(user);
        bank.deposit{value: 1 ether}();
        assertEq(address(bank).balance, 1 ether);
    }

    function testCheckUpkeep() public {
        // 余额等于阈值，不触发
        vm.deal(user, 1 ether);
        vm.prank(user);
        bank.deposit{value: 1 ether}();
        (bool upkeepNeeded, ) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // 余额超过阈值，触发
        vm.deal(user, 0.1 ether);
        vm.prank(user);
        bank.deposit{value: 0.1 ether}();
        (upkeepNeeded, ) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function testPerformUpkeep() public {
        vm.deal(user, 2 ether);
        vm.prank(user);
        bank.deposit{value: 1.2 ether}();

        uint256 balanceBefore = owner.balance;
        
        bank.performUpkeep("");

        uint256 balanceAfter = owner.balance;
        // 应该转移一半余额：1.2 / 2 = 0.6
        assertEq(balanceAfter - balanceBefore, 0.6 ether);
        assertEq(address(bank).balance, 0.6 ether);
    }
}
