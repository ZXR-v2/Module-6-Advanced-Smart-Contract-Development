// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MyWallet {
    string public name;
    mapping(address => bool) private approved;
    address public owner;

    // owner 的存储槽：slot 2
    uint256 private constant OWNER_SLOT = 2;

    modifier auth() {
        address _owner;
        assembly {
            // sload(2) 读出 32 字节，其中低 20 字节是 address
            _owner := sload(OWNER_SLOT)
        }
        require(msg.sender == _owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;

        assembly {
            // owner = msg.sender
            sstore(OWNER_SLOT, caller())
        }
    }

    function transferOwernship(address _addr) external auth {
        require(_addr != address(0), "New owner is the zero address");

        address _owner;
        assembly {
            _owner := sload(OWNER_SLOT)
        }
        require(_owner != _addr, "New owner is the same as the old owner");

        assembly {
            // 写入新 owner
            sstore(OWNER_SLOT, _addr)
        }
    }
}
