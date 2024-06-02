// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Olukayode Peter
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 *
 * This is the contract meant to be governed by DSCEngine. This Contract is just the ERC20 implememntation of our stablecoin system.
 */

contract Venom is ERC20, Ownable, ERC20Burnable {
    error Venom__InvalidAddress();
    error Venom__CanOnlyMintMoreThanZero();
    error Venom__CanOnlyBurnMoreThanZero();
    error Venom__SenderHasNoBalance();

    /**
     * VENOM -> The name of the stable coin
     * VNM -> The symbol of the stable coin
     *
     */

    constructor() ERC20("VENOM", "VNM") Ownable(msg.sender) {}

    /**
     *
     * @param _to The address to which the stable coin is minted to
     * @param _amountToMint The amount to be minted to the given address
     */

    function mint(
        address _to,
        uint256 _amountToMint
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert Venom__InvalidAddress();
        }

        if (_amountToMint == 0) {
            revert Venom__CanOnlyMintMoreThanZero();
        }
        _mint(_to, _amountToMint);
        return true;
    }

    /**
     *
     * @param _amountToBurn The amount of the stable coin to be removed from the system
     */
    function burn(uint256 _amountToBurn) public override onlyOwner {
        if (balanceOf(msg.sender) == 0) {
            revert Venom__SenderHasNoBalance();
        }

        if (_amountToBurn == 0) {
            revert Venom__CanOnlyBurnMoreThanZero();
        }
        super.burn(_amountToBurn);
    }

   
}

//0x4644125567D4Ec322a464f8c8B4bcFEc5359FD72
