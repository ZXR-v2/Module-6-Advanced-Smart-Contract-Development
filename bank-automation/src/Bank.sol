// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Chainlink Automation Interface
interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}

contract Bank is AutomationCompatibleInterface {
    mapping(address => uint256) public balances;
    address public owner;
    uint256 public threshold;

    event Deposited(address indexed user, uint256 amount);
    event UpkeepPerformed(uint256 amountTransferred);

    constructor(uint256 _threshold) {
        owner = msg.sender;
        threshold = _threshold;
    }

    // 用户存款
    function deposit() public payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // Chainlink Automation 检查任务是否需要执行
    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        // 当合约余额超过阈值时返回 true
        upkeepNeeded = address(this).balance > threshold;
    }

    // Chainlink Automation 执行自动化任务
    function performUpkeep(bytes calldata /* performData */) external override {
        // 再次检查以确保安全
        if (address(this).balance > threshold) {
            uint256 amountToTransfer = address(this).balance / 2;
            (bool success, ) = owner.call{value: amountToTransfer}("");
            require(success, "Transfer failed");
            emit UpkeepPerformed(amountToTransfer);
        }
    }
    
    // 允许 Owner 修改阈值
    function setThreshold(uint256 _threshold) external {
        require(msg.sender == owner, "Only owner");
        threshold = _threshold;
    }

    // 允许 Owner 提取剩余资金（可选）
    function withdraw() external {
        require(msg.sender == owner, "Only owner");
        payable(owner).transfer(address(this).balance);
    }

    // 接收原生币
    receive() external payable {
        deposit();
    }
}
