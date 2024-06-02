pragma solidity ^0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Engine} from "./Engine.sol";

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale, allowing investors to purchase tokens. This contract includes functions to be implemented by the inheriting contracts.
 * These functions include:
 * 1) getReceiverAddress() This function when implemented by the inheriting return its address as the receiver
 * 2) transferViper() This function transfers viper from the inheriting contract
 * 3) viperBalanceAfterEarlyAdopters() This function gets the remaining viper balance of the inheriting contract after the early adopters contract finishes
 */
  abstract contract CrowdSale {
    // ERRORS
    error CrowdSale__InvalidParams();
    error Crowdsale__PurchaseNotValid(
        address beneficiary,
        uint256 amount,
        uint256 totalInvestorCap,
        uint256 tokenBalance
    );
    error Crowdsale__TransferFailed();

    // IMMUTABLES
    address private immutable i_viper;
    address private immutable i_weth;
    uint256 private immutable i_startAt;
    uint256 private immutable i_endTime;

    // CONSTANTS
    uint256 private constant INVESTOR_MAX_TOKEN_CAP = 300e18;
    uint256 private constant MIN_WETH_AMOUNT = 3e16;
    uint256 private constant PRECISION = 1e18;

    // EVENT
    event TokenPurchase(
        address purchaser,
        address indexed beneficiary,
        uint256 indexed value,
        uint256 indexed amount
    );

   

    /**
     *
     * @param _weth The address of the valid token to be used to purchase viper
     * @param _viper The address of the governance token to be sold
     * @param _startAt The starting time of the crowdsale
     * @param _duration The time length of the crowdsale
     */
    constructor(
        address _weth,
        address _viper,
        uint256 _startAt,
        uint256 _duration
    ) {
        i_viper = _viper;
        i_weth = _weth;
        i_startAt = block.timestamp + _startAt;
        i_endTime = i_startAt + _duration;
    }

    /**
     * @notice This function issues out token to the beneficiary
     * @param _beneficiary The address on behalf of which the token is bought. A user can buy token on his behalf by passing in his address
     * @param _amount The amount of weth which is used to purchase the viper
     */
    function buyTokens(address _beneficiary, uint256 _amount) public  {
        address engine = getEngineAddress();
        uint256 tokens = getTokenAmount(_amount);
     
        _preValidatePurchase(_beneficiary, _amount, tokens);
        _forwardWeth(_amount, engine);
       
        _processPurchase(_beneficiary, tokens);

        emit TokenPurchase(msg.sender, _beneficiary, _amount, tokens);
    }

       function getTokenAmount(uint256 _amount) public view returns (uint256) {
         address engine = getEngineAddress();
         if (_amount < MIN_WETH_AMOUNT) {
            return 0;
         }   
          return  _getTokenAmount(_amount, engine);
    
       }

    /**
     * @dev Validation of an incoming purchase. This function prevalidates an incoming purchase
     */
    function _preValidatePurchase(
        address _beneficiary,
        uint256 _amount,
        uint256 _tokenAmount
    ) view internal  {
         address engine = getEngineAddress();
        uint256 initialToken = Engine(engine).amountToClaim(_beneficiary);
        uint256 updatedToken = initialToken + _tokenAmount;
        bool validBeneficiary = (_beneficiary != address(0));
        bool validWethAmount = (_amount >= MIN_WETH_AMOUNT);
        bool validTokenAmount = (updatedToken <= INVESTOR_MAX_TOKEN_CAP);
        bool validStartTime = block.timestamp >= i_startAt;
        bool validEndTime = block.timestamp < i_endTime;
    
        bool validParams = (validBeneficiary &&
            validWethAmount &&
            validTokenAmount &&
            validStartTime &&
            validEndTime);
        if (!validParams) {
            revert Crowdsale__PurchaseNotValid(
                _beneficiary,
                _amount,
                INVESTOR_MAX_TOKEN_CAP,
                updatedToken
            );
        }
    }

    /**
     * @notice This function transfer tokens to the beneficiary
     */
    function _deliverTokens(
        address _beneficiary,
        uint256 _tokenAmount
    ) internal {

         transferViper(_beneficiary,  _tokenAmount);
    
    }

    /**
     *@notice This function processes token to be delivered to the beneficiary
     */
    function _processPurchase(
        address _beneficiary,
        uint256 _tokenAmount
    ) internal {
        _deliverTokens(_beneficiary, _tokenAmount);
    }

   

    /**
      @notice This function calculates the total amount of token to be transferred based on the amount of weth passed
     */
    function _getTokenAmount(
        uint256 _amount,
        address _receiver
    ) internal view returns (uint256) {
        return (_amount * PRECISION) / getPrice(_receiver);
    }

    /**
     * @dev @notice This function forwards weth to the receiver address
     */
    function _forwardWeth(uint256 _amount, address _receiver) internal {
        bool success = ERC20(i_weth).transferFrom(
            msg.sender,
            _receiver,
            _amount
        );
        if (!success) {
            revert Crowdsale__TransferFailed();
        }
    }

    /**
     *  @notice This function returns price based on the total weth in the receiver address and the total supply of viper
     */
    function getPrice(address _receiver) internal view returns (uint256) {
        uint256 totalWeth = ERC20(i_weth).balanceOf(_receiver);
        uint256 totalViperMinted = ERC20(i_viper).totalSupply();
        uint256 price = (totalWeth * PRECISION) / totalViperMinted;
        return price;
    }

    function getStartTime() public view returns (uint256) {
        return i_startAt;
    }

    function getEndTime() public view returns (uint256) {
        return i_endTime;
    }

    

    // -----------------------------
    // IMPLEMENTATION FUNCTIONS
    // -----------------------------

    function getEngineAddress() internal view virtual returns  (address);

    function transferViper(address _beneficiary, uint256 _amount) internal virtual;

   

    
}
