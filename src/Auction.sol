// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Venom} from "./Venom.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Engine} from "./Engine.sol";

/**
 * @title A Dutch Auction
 */
contract Auction is Ownable {
    ///CONSTANT
    uint256 private constant PRECISION = 1e18;

    //// ERROR
    error Auction__AuctionExpired(uint256 _endTime);
    error Auction__NotRequiredAmount();
    error Auction__TransferToEngineFailed();
    error Auction__TransferToCallerFailed();
    error Auction__TransferRemainingBalanceFailed();

    /// IMMUTABLES
    uint256 private immutable i_duration;
    IERC20 private immutable i_collateral;
    address private immutable i_engine;
    uint256 private immutable i_startingPrice;
    uint256 private immutable i_discountRate;
    address private immutable i_venom;

    /// STATE
    uint256 private s_amount;
    uint256 private s_startAt;
    uint256 private s_endsAt;

    /**
     * @param _duration The time length of the auction
     * @param _collateral The address of the collateral to be sold off in the auction
     * @param _amount The amount in U.S Dollar to be gotten from the auction
     * @param _engine The address of the seller
     * @param _startingPrice The initial price the auction starts
     * @param _discountRate The discounting factor which discount the price with time
     * @param _venom The address of the token to be used to purchase collaterals
     */
    constructor(
        uint256 _duration,
        address _collateral,
        uint256 _amount,
        address _engine,
        uint256 _startingPrice,
        uint256 _discountRate,
        address _venom
    ) Ownable(_engine) {
        i_duration = _duration;
        i_collateral = IERC20(_collateral);
        s_amount = _amount;
        i_engine = _engine;
        i_startingPrice = _startingPrice;
        s_startAt = block.timestamp;
        s_endsAt = block.timestamp + _duration;
        i_discountRate = _discountRate;
        i_venom = _venom;
    }

    /**
     * @notice The function Which returns the price of collateral to be sold off
     */
    function getPrice() public view returns (uint256) {
        uint256 interval = block.timestamp - s_startAt;
        uint256 rate = i_discountRate * interval;
        return i_startingPrice - rate;
    }

    /**
     * @notice The function to be called to buy collateral
     * @param _amount Thia is the amount of venom that a user intends to buy the collateral with
     */
    function buy(uint256 _amount) public {
        uint256 price = getPrice();
        uint256 amountOfCollateralToTransfer = (_amount * PRECISION) / price;
        if (block.timestamp > s_endsAt) {
            revert Auction__AuctionExpired(s_endsAt);
        }

        if (_amount > s_amount) {
            revert Auction__NotRequiredAmount();
        }

        bool success = IERC20(i_venom).transferFrom(
            msg.sender,
            i_engine,
            _amount
        );
        if (!success) {
            revert Auction__TransferToEngineFailed();
        }

        bool suceessFul = IERC20(i_collateral).transfer(
            msg.sender,
            amountOfCollateralToTransfer
        );
        if (!suceessFul) {
            revert Auction__TransferToCallerFailed();
        }

        s_amount -= _amount;
    }

    /**
     * @notice The function that the engine calls to transfer collateral if there is an remaining balance after the auction
     */
    function transferToEngine() external onlyOwner returns (uint256) {
        uint256 auctionBalance = i_collateral.balanceOf(address(this));
        bool success = IERC20(i_collateral).transfer(i_engine, auctionBalance);
        if (!success) {
            revert Auction__TransferToEngineFailed();
        }

        return (auctionBalance);
    }
   
   /**
    * @notice This fuction updates the auction if the intended collateral has not being sold off 
    */
    function updatePrice() external onlyOwner {
        s_startAt = block.timestamp;
        s_endsAt = block.timestamp + i_duration;
    }

    function getCollateralAmountToLiquidate() external view returns (uint256) {
        return s_amount;
    }

    function getStartingTime() external view returns (uint256) {
        return s_startAt;
    }

    function getEndingTime() external view returns (uint256) {
        return s_endsAt;
    }

    function getAuctionDuration() external view returns (uint256) {
        return i_duration;
    }

    function getAuctionCollateral() external view returns (IERC20) {
        return i_collateral;
    }

    function getstartingPrice() external view returns (uint256) {
        return i_startingPrice;
    }

    function getDiscountRate() external view returns (uint256) {
        return i_discountRate;
    }
}
