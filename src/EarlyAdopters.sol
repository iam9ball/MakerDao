// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

  import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
/**
 *
 * @notice This contract issues governace token (Viper) to the early users of the inheriting contract within the specified duration
 */

 abstract contract EarlyAdopters {
    // ERRORS
    error EarlyAdopters__DepositNotValid(
        address _beneficiary,
        uint256 _maxAmount,
        uint256 _minAmount,
        uint256 _time
    );
    error EarlyAdopters__CannotValidateClaims(
        uint256 _time,
        uint256 _amount,
        bool _claimedReward,
        bool _validTokenBalance
    );
    error EarlyAdopters__DepositFailed(); 

    // IMMUTABLES
    uint256 private immutable i_startAt;
    uint256 private immutable i_endAt;
    uint256 private immutable i_tokenAmountToBeDistributed;
    address private immutable i_viper;
    uint256 private immutable i_claimTime;

    // CONSTANT
    uint256 private constant MIN_PERCENT_TO_DEPOSIT = 1e18;
    uint256 private constant MAX_PERCENT_TO_DEPOSIT = 10e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant PERCENTAGE = 100e18;
    uint256 private constant EARLY_ADOPTERS_MAX_TOKEN_CAP = 300e18;

    // STATES
    uint256 private s_totalDeposited;

    // MAPPINGS
    mapping(address _beneficiary => uint256 _amountDeposited)
        private beneficiaryToAmountDeposited;
    mapping(address _user => bool _rewardClaimed) private userToRewardClaimed;
    mapping(address _beneficiary => uint256 _amountToClaim) private beneficiaryToAmountToClaim;

    // EVENTS
    event RewardClaimed(address indexed _beneficiary, uint256 indexed _amount);

    /**
     *
     * @param _duration This is the specified time length to deposit
     * @param _tokenAmountToBeDistributed This is the total amount of the governance token to be given to the early users
     * @param _viper This is the address of the governance token to be distributed
     * @param _claimTime The valid time in which the early adopters can claim the governance token
     */
    constructor(uint256 _duration, uint256 _tokenAmountToBeDistributed, address _viper, uint256 _claimTime) {
        i_startAt = block.timestamp;
        i_endAt = i_startAt + _duration;
        i_viper = _viper;
        i_tokenAmountToBeDistributed = _tokenAmountToBeDistributed;
        i_claimTime = _claimTime;
    }

    /**
     * @notice The function early adopters interact to deposit token in order to be eligible to claim rewards. This deposit the token into the inheriting contract vault
     * @param _beneficiary The address of user to be deposit on behalf, a user could deposit on behalf of himself by passing in his address
     * @param _amount The amount of token to be deposited
     */

    function deposit(address _beneficiary, uint256 _amount) external {
        uint256 _index = 0;

         _prevalidateDeposit(_beneficiary, _amount);
        address engine = getEngineAddress();
        uint256 tokenAmount = tokenToTransfer(_amount);
        beneficiaryToAmountDeposited[_beneficiary] += _amount;
        beneficiaryToAmountToClaim[_beneficiary] += tokenAmount;
        s_totalDeposited += _amount;
        (bool sucess, ) = engine.call(
            abi.encodeWithSignature(
                "depositCollateral(address,uint256,uint256)",
                msg.sender,
                _index,
                _amount
            )
        );
        if (!sucess) {
            revert EarlyAdopters__DepositFailed();
        }
    }

    /**
     *
     * @notice This function prevalidates the parameters passed before the deposit function is called
     */
    function _prevalidateDeposit(
        address _beneficiary,
        uint256 _amount
    ) internal view {
        uint256 initialAmountDeposited = beneficiaryToAmountDeposited[
            _beneficiary
        ];
        uint256 newAmountToDeposit = initialAmountDeposited + _amount;
        uint256 maxAmountDeposited = maxAmountToDeposit();
        uint256 minAmountDeposited = minAmountToDeposit();
        uint256 totalAmountToBeDistributed = i_tokenAmountToBeDistributed;
        uint256 newTotalDeposited = s_totalDeposited + _amount;

        bool validAddress = _beneficiary != address(0);
        bool validTime = block.timestamp < i_endAt;
        bool validMinAmount = _amount >= minAmountDeposited;
        bool validMaxAmount = newAmountToDeposit <= maxAmountDeposited;
        bool validTotalDeposited = totalAmountToBeDistributed >=
            newTotalDeposited;

        bool validParams = (validAddress &&
            validTime &&
            validMinAmount &&
            validMaxAmount &&
            validTotalDeposited);
        if (!validParams) {
            revert EarlyAdopters__DepositNotValid(
                _beneficiary,
                maxAmountDeposited,
                minAmountDeposited,
                block.timestamp
            );
        }
    }

    /**
     * @notice This is the function that will be called by the users to claim rewards after a certain time
     */
    function claimRewards() external {
        uint256 userAmountDeposited = beneficiaryToAmountDeposited[msg.sender];
        bool userClaimedReward = userToRewardClaimed[msg.sender];
        uint256 balanceOfUser = ERC20(i_viper).balanceOf(msg.sender);
        uint256 amountTokenToTransfer = tokenToTransfer(userAmountDeposited);
        _prevalidateClaims(
            userClaimedReward,
            userAmountDeposited,
            balanceOfUser,
            amountTokenToTransfer
        );
        userToRewardClaimed[msg.sender] = true;
        transferViper(msg.sender, amountTokenToTransfer);
        emit RewardClaimed(msg.sender, amountTokenToTransfer);
    }

    /**
     *
     * @notice This function prevalidates when the claim reward function can be called by the early users
     */

    function _prevalidateClaims(
        bool _rewardClaimed,
        uint256 _amountDeposited,
        uint256 _userTokenBalance,
        uint256 _userTokenToTransfer
    ) internal view {
        uint256 claimTime = i_claimTime;
        uint256 initialTokenBalance = _userTokenBalance;
        uint256 newTokenBalance = initialTokenBalance + _userTokenToTransfer;
        uint256 endClaimTime = claimTime + 10 days;
        bool validClaimAmount = _amountDeposited > 0;
        bool validTime = block.timestamp >= claimTime && block.timestamp < endClaimTime;
        bool validRewardToClaim = _rewardClaimed == false;
        bool validTokenBalance = newTokenBalance <=
            EARLY_ADOPTERS_MAX_TOKEN_CAP;
        bool validParams = validTime &&
            validRewardToClaim &&
            validClaimAmount &&
            validTokenBalance;

        if (!validParams) {
            revert EarlyAdopters__CannotValidateClaims(
                block.timestamp,
                _amountDeposited,
                _rewardClaimed,
                validTokenBalance
            );
        }
    }



    /**
     *
     * @notice This function calculates the total amount of token to be transferred based on the amount deposited by the user
     * @param _amount The amount of weth to be passed in to check the amount of governance token to be issued
     */

    function tokenToTransfer(uint256 _amount) public view returns (uint256) {
        uint256 totalTokenDepositedPercentage = (_amount * PRECISION) /
            i_tokenAmountToBeDistributed;
        uint256 amountTokenToTransfer = (totalTokenDepositedPercentage *
            i_tokenAmountToBeDistributed) / PRECISION;
        return amountTokenToTransfer;
    }
    
    /**
     * @notice This function returns the amount an address can claim 
     * @param _user This is the address of the user to check amount to claim
     */
    function amountToClaim(address _user) external view returns (uint256) {
        return beneficiaryToAmountToClaim[_user];
    }

    /**
     * @notice This function returns the maximum amount a user can deposit to get the maximum amount an address can claim of the total token to be distributed
     */

    function maxAmountToDeposit() public view returns (uint256) {
        return
            (((MAX_PERCENT_TO_DEPOSIT * PRECISION) / PERCENTAGE) *
                i_tokenAmountToBeDistributed) / PRECISION;
    }

    /**
     * @notice This function returns the minimum amount a user can deposit at a single transaction to get a claim of the total token to be distributed. This is in order to avoid locking up funds of user that is not enough to claim a reward
     */

    function minAmountToDeposit() public view returns (uint256) {
        return
            (((MIN_PERCENT_TO_DEPOSIT * PRECISION) / PERCENTAGE) *
                i_tokenAmountToBeDistributed) / PRECISION;
    }

   
   //IMPLEMENTATION

   function getEngineAddress() internal view virtual returns (address);

   function transferViper(address _beneficiary, uint256 _amount) internal virtual;
   

    
    function getUserDepositBalance(
        address _user
    ) external view returns (uint256) {
        return beneficiaryToAmountDeposited[_user];
    }

    function getUserClaimedReward(address _user) external view returns (bool) {
        return userToRewardClaimed[_user];
    }

    function getTotalTokenToTransfer() external view returns (uint256) {
        return i_tokenAmountToBeDistributed;
    }

    function getTotalDeposited() external view returns (uint256) {
        return s_totalDeposited;
    }

    function getEarlyAdoptersEndTime() external view returns (uint256) {
        return i_endAt;
    }

}

    

    
   
