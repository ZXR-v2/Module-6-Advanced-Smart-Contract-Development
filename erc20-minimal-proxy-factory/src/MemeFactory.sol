// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MemeToken.sol";

/**
 * @title MemeFactory
 * @dev 使用最小代理模式创建Meme代币的工厂合约
 */
contract MemeFactory {
    address public immutable implementation;
    address public immutable projectOwner;
    
    // 项目方收费比例 (1%)
    uint256 public constant PROJECT_FEE_PERCENT = 1;
    
    // 记录所有创建的Meme代币
    address[] public allMemes;
    mapping(address => bool) public isMeme;
    
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
    
    constructor() {
        implementation = address(new MemeToken());
        projectOwner = msg.sender;
    }
    
    /**
     * @dev 部署新的Meme代币
     * @param symbol 代币符号
     * @param totalSupply 总发行量
     * @param perMint 每次铸造数量
     * @param price 每个代币的价格(wei)
     * @return memeToken 新创建的Meme代币地址
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address memeToken) {
        require(totalSupply > 0, "Invalid total supply");
        require(perMint > 0 && perMint <= totalSupply, "Invalid per mint");
        
        // 使用最小代理创建新实例
        memeToken = _clone(implementation);
        
        // 初始化新代币
        MemeToken(memeToken).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender,  // issuer
            address(this) // factory
        );
        
        // 记录
        allMemes.push(memeToken);
        isMeme[memeToken] = true;
        
        emit MemeDeployed(
            memeToken,
            msg.sender,
            symbol,
            totalSupply,
            perMint,
            price
        );
    }
    
    /**
     * @dev 铸造Meme代币
     * @param tokenAddr Meme代币地址
     */
    function mintMeme(address tokenAddr) external payable {
        require(isMeme[tokenAddr], "Not a valid meme token");
        
        MemeToken meme = MemeToken(tokenAddr);
        uint256 perMint = meme.perMint();
        uint256 price = meme.price();
        
        // 计算总费用 (perMint has 18 decimals, so we divide by 1e18)
        uint256 totalCost = (perMint * price) / 1e18;
        require(msg.value >= totalCost, "Insufficient payment");
        
        // 铸造代币
        uint256 minted = meme.mint(msg.sender);
        require(minted == perMint, "Mint failed");
        
        // 分配费用
        uint256 projectFee = (totalCost * PROJECT_FEE_PERCENT) / 100;
        uint256 issuerFee = totalCost - projectFee;
        
        // 转账给项目方
        if (projectFee > 0) {
            (bool success1, ) = projectOwner.call{value: projectFee}("");
            require(success1, "Project fee transfer failed");
        }
        
        // 转账给发行者
        if (issuerFee > 0) {
            (bool success2, ) = meme.issuer().call{value: issuerFee}("");
            require(success2, "Issuer fee transfer failed");
        }
        
        // 退还多余的ETH
        if (msg.value > totalCost) {
            (bool success3, ) = msg.sender.call{value: msg.value - totalCost}("");
            require(success3, "Refund failed");
        }
        
        emit MemeMinted(
            tokenAddr,
            msg.sender,
            minted,
            totalCost,
            projectFee,
            issuerFee
        );
    }
    
    /**
     * @dev 获取所有Meme代币数量
     */
    function getMemeCount() external view returns (uint256) {
        return allMemes.length;
    }
    
    /**
     * @dev 获取指定索引的Meme代币地址
     */
    function getMeme(uint256 index) external view returns (address) {
        require(index < allMemes.length, "Index out of bounds");
        return allMemes[index];
    }
    
    /**
     * @dev 最小代理克隆实现 (EIP-1167)
     */
    function _clone(address _implementation) private returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, _implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "Clone failed");
    }
}
