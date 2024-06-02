// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract WETH is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for ERC20;

    constructor() ERC20("Wrapped ETH", "WETH") Ownable(msg.sender) {}

    function mint(address _beneficiary, uint256 amount) external onlyOwner {
        _mint(_beneficiary, amount);
    }
}

//200000000000000000000000

// 0x0Ba1a13a9bD1A75F6B09D0deb7afb59DA209d44d weth
// 0x1a4c1cce6606397f773135bdce0ccd0f361ce5f3 UDST
