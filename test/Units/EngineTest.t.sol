// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {DeployEngine} from "../../script/DeployEngine.s.sol";
import {Engine} from "../../src/Engine.sol";
import {NetworkConfig} from "../../script/Config/NetworkConfig.sol";
import {Venom} from "../../src/Venom.sol";
import {TimeLock} from "../../src/TimeLock.sol";
import {Viper} from "../../src/Viper.sol";
import {Ancestors} from "../../src/Ancestors.sol";
import {WETH} from "../../src/weth.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockV3Aggregator} from "../Mocks/MockV3Aggregator.sol";
import {EarlyAdopters} from "../../src/EarlyAdopters.sol";
import {CrowdSale} from "../../src/CrowdSale.sol";
import {Vm} from "forge-std/Vm.sol";

contract EngineTest is Test {
    DeployEngine deployer;
    Engine engine;
    NetworkConfig network;
    Venom venom;
    TimeLock timeLock;
    Viper viper;
    Ancestors ancestors;
    address WALLET_ADDRESS;
    address weth;
    address pricefeed;


     address[] targets;
     uint256[]  values;
     bytes[]  calldatas;

    uint256 private constant actualLiquidationThreshold = 150e18;
    uint256 private constant actualPenaltyFee = 1 ether;
    uint256 private constant actualStabilityFee = 3e15;
    uint256 private constant totalTokenDeposited = 8000e18;

    uint256 private constant EARLY_ADOPTERS_MIN_AMOUNT_TO_DEPOSIT = 30e18;
    uint256 private constant EARLY_ADOPTERS_MAX_AMOUNT_TO_DEPOSIT = 300e18;
    uint256 private constant EARLY_ADOPTERS_MAX_TOKEN_CAP = 300e18;
    uint256 private constant TOTAL_TOKEN_DEPOSITED = 8000e18;
    uint256 private constant WETH_MINT_AMOUNT = 10000e18;
    uint256 private constant VOTING_DELAY = 7200;
    uint256 private constant VOTING_PERIOD = 50400;
     uint256 private constant MIN_DELAY = 7 days;

    uint256 private constant CROWDSALE_INVESTOR_MAX_TOKEN_CAP = 300e18;

    event CollateralDeposited(
        address indexed _from,
        address indexed collateralDeposited,
        uint256 indexed _amountToDeposit
    );
    event RewardClaimed(address indexed _beneficiary, uint256 indexed _amount);

    function setUp() external {
        deployer = new DeployEngine();
        (
            engine,
            network,
            venom,
            timeLock,
            viper,
            ancestors,
            WALLET_ADDRESS
        ) = deployer.run();
        (weth, pricefeed, , , , ) = network.activeNetworkConfig();
        for (uint160 i = 1; i < 12; i++) {
            vm.startPrank(WALLET_ADDRESS);
            WETH(weth).mint(address(i), WETH_MINT_AMOUNT);

            vm.stopPrank();
        }
    }

    // ------------------------
    // CONSTRUCTOR TEST
    //--------------------------
    function testCollateralInitializes() external {
        uint256 index = 0;

        (
            address collateralAddress,
            address collateralPricefeed,
            uint256 liquidationThreshold,
            uint256 penaltyFee,
            uint256 stabilityFee
        ) = engine.getCollateralInfo(index);

        assertEq(collateralAddress, weth);
        assertEq(collateralPricefeed, pricefeed);
        assertEq(liquidationThreshold, actualLiquidationThreshold);
        assertEq(penaltyFee, actualPenaltyFee);
        assertEq(stabilityFee, actualStabilityFee);
    }

    //     //----------------------------
    //     // EARLY ADOPTERS DEPOSIT TEST
    //     //-----------------------------
    function testEarlyAdoptersDepositRevertsWithInvalidAddress() external {
        address beneficiary = address(0);
        uint256 amount = 30e18;

        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                EarlyAdopters.EarlyAdopters__DepositNotValid.selector,
                beneficiary,
                EARLY_ADOPTERS_MAX_AMOUNT_TO_DEPOSIT,
                EARLY_ADOPTERS_MIN_AMOUNT_TO_DEPOSIT,
                block.timestamp
            )
        );
        engine.deposit(beneficiary, amount);
        vm.stopPrank();
    }

    function testEarlyAdoptersDepositRevertsWithInvalidAmount() external {
        address beneficiary = address(1);
        uint256 amount = 301e18;
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                EarlyAdopters.EarlyAdopters__DepositNotValid.selector,
                beneficiary,
                EARLY_ADOPTERS_MAX_AMOUNT_TO_DEPOSIT,
                EARLY_ADOPTERS_MIN_AMOUNT_TO_DEPOSIT,
                block.timestamp
            )
        );

        engine.deposit(beneficiary, amount);
        vm.stopPrank();
    }

    function testEarlyAdoptersDeposiRevertsWithInValidTime() external {
        address beneficiary = address(1);
        uint256 amount = 50e18;
        uint256 earlyAdoptersDuration = engine.getEarlyAdoptersDuration();
        vm.warp(block.timestamp + earlyAdoptersDuration + 1);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                EarlyAdopters.EarlyAdopters__DepositNotValid.selector,
                beneficiary,
                EARLY_ADOPTERS_MAX_AMOUNT_TO_DEPOSIT,
                EARLY_ADOPTERS_MIN_AMOUNT_TO_DEPOSIT,
                block.timestamp
            )
        );
        engine.deposit(beneficiary, amount);
        vm.stopPrank();
    }

    function testEarlyAdoptersDepositRevertsWithInvalidTotalAmountDeposited()
        external
    {
        uint256 amount = 300e18;
        for (uint160 i = 1; i < 11; i++) {
            vm.startPrank(address(i));
            ERC20(weth).approve(address(engine), amount);
            engine.deposit(address(uint160(i)), amount);
        }

        vm.startPrank(address(11));
        ERC20(weth).approve(address(engine), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                EarlyAdopters.EarlyAdopters__DepositNotValid.selector,
                address(11),
                EARLY_ADOPTERS_MAX_AMOUNT_TO_DEPOSIT,
                EARLY_ADOPTERS_MIN_AMOUNT_TO_DEPOSIT,
                block.timestamp
            )
        );
        engine.deposit(address(11), amount);
        vm.stopPrank();
    }

    function testEarlyAdoptersDepositWorksWithValidParams() external {
        address beneficiary = address(1);
        uint256 amount = 50e18;
        console.log(ERC20(weth).balanceOf(address(1)));
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), amount);
        engine.deposit(beneficiary, amount);
        vm.stopPrank();
    }

    modifier earlyAdoptersDeposited() {
        uint256 amount = 300e18;
        for (uint256 i = 1; i < 11; i++) {
            vm.startPrank(address(uint160(i)));
            ERC20(weth).approve(address(engine), amount);
            engine.deposit(address(uint160(i)), amount);
            vm.stopPrank();
        }
        _;
    }

    function testEarlyAdoptersDepositsToEngine()
        external
        earlyAdoptersDeposited
    {
        uint256 engineWethBalance = ERC20(weth).balanceOf(address(engine));
        assertEq(engineWethBalance, 3000e18);
    }

    function testEarlyAdoptersDepositEmitsCollateralDeposited() external {
        uint256 amount = 30e18;
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), amount);
        vm.expectEmit(true, true, true, false, address(engine));

        emit CollateralDeposited(address(1), weth, amount);

        engine.deposit(address(1), amount);
        vm.stopPrank();
    }

    //-------------------------------
    //EARLY ADOPTERS CLAIM REWARD TEST
    //---------------------------------

    function testAmountToClaim() external earlyAdoptersDeposited {
        address user1 = address(1);
        uint256 amountToClaim = engine.amountToClaim(user1);
        assertEq(amountToClaim, 300e18);
    }

    function testClaimRewardRevertsWhenTimeNotReached()
        external
        earlyAdoptersDeposited
    {
        uint256 amount = engine.amountToClaim(address(1));
        bool rewardClaimed = engine.getUserClaimedReward(address(1));
        uint256 balanceOfUser = ERC20(viper).balanceOf(address(1));
        uint256 userTokenToTransfer = engine.tokenToTransfer(amount);
        bool validTokenToTransfer = userTokenToTransfer + balanceOfUser <=
            EARLY_ADOPTERS_MAX_TOKEN_CAP;
        vm.startPrank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                EarlyAdopters.EarlyAdopters__CannotValidateClaims.selector,
                block.timestamp,
                amount,
                rewardClaimed,
                validTokenToTransfer
            )
        );
        engine.claimRewards();
        vm.stopPrank();
    }

    function testClaimRewardWorksWhenTimeReached()
        external
        earlyAdoptersDeposited
    {
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();
        uint256 userViperAmountToClaim = engine.amountToClaim(address(1));
        vm.warp(block.timestamp + crowdSaleStartAt + crowdSaleDuration + 1);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));

        engine.claimRewards();
        vm.stopPrank();
        uint256 userViperBalance = ERC20(viper).balanceOf(address(1));
        assertEq(userViperAmountToClaim, userViperBalance);
    }

    function testUserCanNotClaimRewardsIfNotDeposited() external {
        uint256 amount = engine.getUserDepositBalance(address(1));
        bool rewardClaimed = engine.getUserClaimedReward(address(1));
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();
        uint256 balanceOfUser = ERC20(viper).balanceOf(address(1));
        uint256 userTokenToTransfer = engine.tokenToTransfer(amount);
        bool validTokenToTransfer = balanceOfUser + userTokenToTransfer <=
            EARLY_ADOPTERS_MAX_TOKEN_CAP;
        vm.warp(crowdSaleStartAt + crowdSaleDuration + 1);
        vm.roll(block.number + 1);

        vm.startPrank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                EarlyAdopters.EarlyAdopters__CannotValidateClaims.selector,
                block.timestamp,
                amount,
                rewardClaimed,
                validTokenToTransfer
            )
        );
        engine.claimRewards();
        vm.stopPrank();
    }

    modifier userClaimedReward() {
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();
        vm.warp(block.timestamp + crowdSaleStartAt + crowdSaleDuration + 1);
        vm.roll(block.number + 1);
        for (uint160 i = 1; i < 11; i++) {
            vm.startPrank(address(i));
            engine.claimRewards();
            viper.delegate(address(i));
            vm.stopPrank();
        }
        _;
    }

    function testUserCannotReclaimRewardsAfterInitialClaim()
        external
        earlyAdoptersDeposited
        userClaimedReward
    {
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();
        uint256 amount = engine.getUserDepositBalance(address(1));
        bool claimedReward = engine.getUserClaimedReward(address(1));
        uint256 balanceOfUser = ERC20(viper).balanceOf(address(1));
        uint256 userTokenToTransfer = engine.tokenToTransfer(amount);
        bool validTokenToTransfer = balanceOfUser + userTokenToTransfer <=
            EARLY_ADOPTERS_MAX_TOKEN_CAP;
        vm.startPrank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                EarlyAdopters.EarlyAdopters__CannotValidateClaims.selector,
                block.timestamp,
                amount,
                claimedReward,
                validTokenToTransfer
            )
        );
        engine.claimRewards();

        vm.stopPrank();
    }

    function testUserReceivesViperAfterClaimingRewards()
        external
        earlyAdoptersDeposited
    {
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();
        uint256 userPreviousViperBalance = ERC20(viper).balanceOf(address(1));
        vm.warp(block.timestamp + crowdSaleStartAt + crowdSaleDuration + 1);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));

        engine.claimRewards();

        vm.stopPrank();
        uint256 userPresentViperBalance = ERC20(viper).balanceOf(address(1));

        assert(userPresentViperBalance > userPreviousViperBalance);
    }

    function testEarlyAdoptersClaimRewardsEmitsRewardClaimed()
        external
        earlyAdoptersDeposited
    {
        uint256 amount = engine.getUserDepositBalance(address(1));
        uint256 tokenToTransfer = engine.tokenToTransfer(amount);
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();
        vm.warp(block.timestamp + crowdSaleStartAt + crowdSaleDuration + 1);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        vm.expectEmit(true, true, false, false, address(engine));
        emit RewardClaimed(address(1), tokenToTransfer);
        engine.claimRewards();

        vm.stopPrank();
    }

    function testTokenToTransferFromEvent() external earlyAdoptersDeposited {
        uint256 amount = engine.getUserDepositBalance(address(1));
        uint256 tokenToTransfer = engine.tokenToTransfer(amount);
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();
        vm.warp(block.timestamp + crowdSaleStartAt + crowdSaleDuration + 1);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        vm.recordLogs();
        engine.claimRewards();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 tokenAmount = entries[1].topics[2];
        assertEq(tokenToTransfer, uint256(tokenAmount));
    }

    function testEarlyAdoptersClaimRewardRevertsWithInvalidClaimTime()
        external
        earlyAdoptersDeposited
    {
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();
        uint256 amount = engine.getUserDepositBalance(address(1));
        bool claimedReward = engine.getUserClaimedReward(address(1));
        uint256 balanceOfUser = ERC20(viper).balanceOf(address(1));
        uint256 userTokenToTransfer = engine.tokenToTransfer(amount);
        bool validTokenToTransfer = balanceOfUser + userTokenToTransfer <=
            EARLY_ADOPTERS_MAX_TOKEN_CAP;
        vm.warp(
            block.timestamp + crowdSaleStartAt + crowdSaleDuration + 10 days + 1
        );
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                EarlyAdopters.EarlyAdopters__CannotValidateClaims.selector,
                block.timestamp,
                amount,
                claimedReward,
                validTokenToTransfer
            )
        );
        engine.claimRewards();

        vm.stopPrank();
    }

    //     //-----------------------
    //    //CROWD SALE TEST
    //   //-----------------------

    function testGetTokenAmount() external earlyAdoptersDeposited {
        uint256 _amount = 1e18;
        uint256 actualTokenAmount = engine.getTokenAmount(_amount);
        uint256 expectedTokenAmount = 3333333333333333333;
        assertEq(actualTokenAmount, expectedTokenAmount);
    }

    function testCrowdSaleCannotBuyTokenWithInvalidAddress()
        external
        earlyAdoptersDeposited
    {
        address _beneficiary = address(0);
        uint256 _amount = 1e18;
        uint256 initialTokenAmount = engine.amountToClaim(_beneficiary);
        uint256 _tokenAmount = engine.getTokenAmount(_amount);
        uint256 updatedToken = initialTokenAmount + _tokenAmount;
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        vm.warp(block.timestamp + crowdSaleStartAt);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdSale.Crowdsale__PurchaseNotValid.selector,
                _beneficiary,
                _amount,
                CROWDSALE_INVESTOR_MAX_TOKEN_CAP,
                updatedToken
            )
        );

        engine.buyTokens(_beneficiary, _amount);
        vm.stopPrank();
    }

    function testCrowdSaleRevertsWithInvalidMinAmount()
        external
        earlyAdoptersDeposited
    {
        address _beneficiary = address(13);
        uint256 _amount = 2e16;
        uint256 initialTokenAmount = engine.amountToClaim(_beneficiary);
        uint256 _tokenAmount = engine.getTokenAmount(_amount);
        uint256 updatedToken = initialTokenAmount + _tokenAmount;
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        vm.warp(block.timestamp + crowdSaleStartAt);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 2e16);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdSale.Crowdsale__PurchaseNotValid.selector,
                _beneficiary,
                _amount,
                CROWDSALE_INVESTOR_MAX_TOKEN_CAP,
                updatedToken
            )
        );

        engine.buyTokens(_beneficiary, _amount);
        vm.stopPrank();
    }

    function testCrowdSaleRevertsWithInvalidMaxAmount()
        external
        earlyAdoptersDeposited
    {
        address _beneficiary = address(13);
        uint256 _amount = 91e18;
        uint256 initialTokenAmount = engine.amountToClaim(_beneficiary);
        uint256 _tokenAmount = engine.getTokenAmount(_amount);
        uint256 updatedToken = initialTokenAmount + _tokenAmount;
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        vm.warp(block.timestamp + crowdSaleStartAt);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 91e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdSale.Crowdsale__PurchaseNotValid.selector,
                _beneficiary,
                _amount,
                CROWDSALE_INVESTOR_MAX_TOKEN_CAP,
                updatedToken
            )
        );

        engine.buyTokens(_beneficiary, _amount);
        vm.stopPrank();
    }

    function testCrowdSaleRevertsWithInvalidTime()
        external
        earlyAdoptersDeposited
    {
        address _beneficiary = address(13);
        uint256 _amount = 90e18;
        uint256 initialTokenAmount = engine.amountToClaim(_beneficiary);
        uint256 _tokenAmount = engine.getTokenAmount(_amount);
        uint256 updatedToken = initialTokenAmount + _tokenAmount;

        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 90e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdSale.Crowdsale__PurchaseNotValid.selector,
                _beneficiary,
                _amount,
                CROWDSALE_INVESTOR_MAX_TOKEN_CAP,
                updatedToken
            )
        );

        engine.buyTokens(_beneficiary, _amount);
        vm.stopPrank();
    }

    function testCrowdSaleRevertsWhenTimePasses()
        external
        earlyAdoptersDeposited
    {
        address _beneficiary = address(13);
        uint256 _amount = 90e18;
        uint256 initialTokenAmount = engine.amountToClaim(_beneficiary);
        uint256 _tokenAmount = engine.getTokenAmount(_amount);
        uint256 updatedToken = initialTokenAmount + _tokenAmount;
        uint256 crowdSaleEndTime = engine.getEndTime();
        vm.warp(block.timestamp + crowdSaleEndTime);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 90e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdSale.Crowdsale__PurchaseNotValid.selector,
                _beneficiary,
                _amount,
                CROWDSALE_INVESTOR_MAX_TOKEN_CAP,
                updatedToken
            )
        );

        engine.buyTokens(_beneficiary, _amount);
        vm.stopPrank();
    }

    function testCrowdSaleBuyTokensWorks() external earlyAdoptersDeposited {
        address _beneficiary = address(13);
        uint256 _amount = 90e18;
        uint256 _tokenAmount = engine.getTokenAmount(_amount);
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 previousEngineWethBalance = ERC20(weth).balanceOf(
            address(engine)
        );
        uint256 previousBeneficiaryViperBalance = ERC20(viper).balanceOf(
            _beneficiary
        );
        vm.warp(block.timestamp + crowdSaleStartAt);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 90e18);
        engine.buyTokens(_beneficiary, _amount);
        vm.stopPrank();
        uint256 presentEngineWethBalance = ERC20(weth).balanceOf(
            address(engine)
        );
        uint256 presentBeneficiaryViperBalance = ERC20(viper).balanceOf(
            _beneficiary
        );
        assert(presentEngineWethBalance > previousEngineWethBalance);
        assert(
            presentBeneficiaryViperBalance > previousBeneficiaryViperBalance
        );
    }

    function testEarlyAdoptersCanBuyTokenFromCrowdSaleIfNotMaxAmountToClaim()
        external
    {
        uint256 amountToDeposit = 150e18;
        address _beneficiary = address(1);
        vm.startPrank(_beneficiary);
        ERC20(weth).approve(address(engine), amountToDeposit);
        engine.deposit(_beneficiary, amountToDeposit);
        vm.stopPrank();

        uint256 _amount = 225e16;
        uint256 _tokenAmount = engine.getTokenAmount(_amount);
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        vm.warp(block.timestamp + crowdSaleStartAt);
        vm.roll(block.number + 1);
        vm.startPrank(_beneficiary);
        ERC20(weth).approve(address(engine), _amount);
        engine.buyTokens(_beneficiary, _amount);
        vm.stopPrank();
    }

    function testCrowdSaleCannotBuyTokenForAddressWithMaxAmountToClaim()
        external
        earlyAdoptersDeposited
    {
        address _beneficiary = address(2);
        uint256 _amount = 90e18;
        uint256 initialTokenAmount = engine.amountToClaim(_beneficiary);
        uint256 _tokenAmount = engine.getTokenAmount(_amount);
        uint256 updatedToken = initialTokenAmount + _tokenAmount;
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        vm.warp(block.timestamp + crowdSaleStartAt);
        vm.roll(block.number + 1);
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 90e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdSale.Crowdsale__PurchaseNotValid.selector,
                _beneficiary,
                _amount,
                CROWDSALE_INVESTOR_MAX_TOKEN_CAP,
                updatedToken
            )
        );

        engine.buyTokens(_beneficiary, _amount);
        vm.stopPrank();
    }

    //--------------------
    // ENGINE TEST
    //--------------------

    function testMintStateStartAtClosed() external {
        uint256 mintState = engine.getMintState();
        assertEq(mintState, 0);
    }

    function testMintStateAndViperBalanceUpdatesWhenEarlyAdoptersClaimDurationEnds()
        external
    {
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();

        vm.warp(
            block.timestamp + crowdSaleStartAt + crowdSaleDuration + 10 days
        );
        vm.roll(block.number + 1);
        engine.performUpkeep("");
        uint256 engineViperBalance = ERC20(viper).balanceOf(address(engine));
        uint256 mintState = engine.getMintState();
        assertEq(engineViperBalance, 0);
        assertEq(mintState, 1);
    }

    function testMintRevertsWhenMintNotOpen() external earlyAdoptersDeposited {
        vm.startPrank(address(1));
        vm.expectRevert(Engine.Engine__MintNotOpen.selector);

        engine.mint(10e18, 0);
        vm.stopPrank();
    }

    modifier mintStateChanged() {
        uint256 crowdSaleStartAt = engine.getCrowdSaleStartAt();
        uint256 crowdSaleDuration = engine.getCrowdDuration();

        vm.warp(
            block.timestamp + crowdSaleStartAt + crowdSaleDuration + 10 days
        );
        vm.roll(block.number + 1);
        engine.performUpkeep("");
        _;
    }

    function testMintWorksWhenOpen()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        vm.startPrank(address(1));
        engine.mint(10e18, 0);
        vm.stopPrank();
    }

    function testMintRevertsWithZero()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        vm.startPrank(address(1));
        vm.expectRevert(Engine.Engine__NeedsMoreThanZero.selector);
        engine.mint(0, 0);
        vm.stopPrank();
    }

    function testMintRevertsWithBadHealthFactor() external mintStateChanged {
        uint256 amount = 10e18;
        vm.startPrank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                Engine.Engine__BreaksHealthFactor.selector,
                amount
            )
        );
        engine.mint(amount, 0);
        vm.stopPrank();
    }

    function testMintRevertsWithInvalidDebtCeiling()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        uint256 debtCeiling = engine.getDebtCeiling();
        vm.startPrank(WALLET_ADDRESS);
        WETH(weth).mint(address(1), 15000e18);
        vm.stopPrank();

        uint256 amount = 10001e18;
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 15000e18);
        engine.depositCollateral(address(1), 0, 15000e18);
        vm.expectRevert(
            (
                abi.encodeWithSelector(
                    Engine.Engine__CannotValidateMint.selector,
                    block.timestamp,
                    debtCeiling
                )
            )
        );
        engine.mint(amount, 0);
        vm.stopPrank();
    }

    function testMintWorks()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        uint256 previousUserAmountVenomMinted = ERC20(venom).balanceOf(
            address(1)
        );
        vm.startPrank(address(1));
        engine.mint(10e18, 0);
        vm.stopPrank();
        address user = engine.getMinted(0);
        bool minted = engine.getUserMinted(address(1));
        uint256 presentUserAmountVenomMinted = ERC20(venom).balanceOf(
            address(1)
        );
        uint256 userBlockNumber = engine.getUserBlockNumber(address(1));
        assertEq(user, address(1));
        assertEq(minted, true);
        assert(presentUserAmountVenomMinted > previousUserAmountVenomMinted);
        console.log(userBlockNumber);
    }

    function testDepositCollateralRevertsWithZero()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        vm.startPrank(WALLET_ADDRESS);
        WETH(weth).mint(address(13), 15000e18);
        vm.stopPrank();
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 15000e18);

        vm.expectRevert(Engine.Engine__NeedsMoreThanZero.selector);
        engine.depositCollateral(address(13), 0, 0);
        vm.stopPrank();
    }

    function testDepositCollateralRevertsWithInvalidIndex()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        vm.startPrank(WALLET_ADDRESS);
        WETH(weth).mint(address(13), 15000e18);
        vm.stopPrank();
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 15000e18);

        vm.expectRevert(Engine.Engine__CollateralDoesNotExist.selector);
        engine.depositCollateral(address(13), 1, 15000e18);
        vm.stopPrank();
    }

    function testDepositCollateralWorks()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        vm.startPrank(WALLET_ADDRESS);
        WETH(weth).mint(address(13), 15000e18);
        vm.stopPrank();
        uint256 previousEngineWethBalance = ERC20(weth).balanceOf(
            address(engine)
        );
        vm.startPrank(address(13));
        ERC20(weth).approve(address(engine), 15000e18);
        engine.depositCollateral(address(13), 0, 15000e18);
        vm.stopPrank();
        uint256 presentEngineWethBalance = ERC20(weth).balanceOf(
            address(engine)
        );
        assert(presentEngineWethBalance > previousEngineWethBalance);
    }

    modifier depositedCollateral() {
        vm.startPrank(WALLET_ADDRESS);
        WETH(weth).mint(address(1), 15000e18);
        vm.stopPrank();
        vm.startPrank(address(1));
        ERC20(weth).approve(address(engine), 15000e18);
        engine.depositCollateral(address(1), 0, 15000e18);
        vm.stopPrank();
        _;
    }

    modifier mintedVenom() {
        vm.startPrank(address(1));
        engine.mint(100e18, 0);
        vm.stopPrank();
        _;
    }

    function testDepositAndVenom()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        vm.startPrank(WALLET_ADDRESS);
        WETH(weth).mint(address(13), 15000e18);
        vm.stopPrank();
        vm.startPrank(address(13));
        ERC20(weth).approve(address(engine), 15000e18);
        engine.depositCollateralAndMintVenom(0, address(13), 15000e18, 100e18);
        vm.stopPrank();
    }

    function testRedeemCollateralRevertWithInvalidIndex()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        vm.startPrank(address(1));
        vm.expectRevert(Engine.Engine__CollateralDoesNotExist.selector);
        engine.redeemCollateral(1, 300e18);
        vm.stopPrank();
    }

    function testRedeemCollateralRevertWithZero()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        vm.startPrank(address(1));
        vm.expectRevert(Engine.Engine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(0, 0);
        vm.stopPrank();
    }

    function testRedeemCollateralRevertsWhenNotDeposited()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        vm.startPrank(WALLET_ADDRESS);
        WETH(weth).mint(address(13), 15000e18);
        vm.stopPrank();
        uint256 userCollateralBalance = engine.getUserCollateralBalance(
            address(13),
            0
        );
        vm.startPrank(address(13));
        vm.expectRevert(
            abi.encodeWithSelector(
                Engine.Engine__CannotRedeemCollateral.selector,
                userCollateralBalance
            )
        );
        engine.redeemCollateral(0, 300e18);
        vm.stopPrank();
    }

    function testRedeemCollateralRevertsWithInvalidAmountToRedeem()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        uint256 userCollateralBalance = engine.getUserCollateralBalance(
            address(1),
            0
        );
        vm.startPrank(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                Engine.Engine__CannotRedeemCollateral.selector,
                userCollateralBalance
            )
        );
        engine.redeemCollateral(0, 301e18);
        vm.stopPrank();
    }

    function testRedeemCollateralWorks()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        uint256 previousUserWethBalance = ERC20(weth).balanceOf(address(1));
        vm.startPrank(address(1));
        engine.redeemCollateral(0, 300e18);
        vm.stopPrank();
        uint256 presentUserWethBalance = ERC20(weth).balanceOf(address(1));
        assert(presentUserWethBalance > previousUserWethBalance);
    }

    function testRedeemCollateralForVenomWorksWhenUserBurnsTotalMinted()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
        mintedVenom
    {
        uint256 userPreviousVenomBalance = ERC20(venom).balanceOf(address(1));
        uint256 userPreviousWethBalance = ERC20(weth).balanceOf(address(1));
        uint256 enginePreviousVenomBalance = ERC20(venom).balanceOf(
            address(engine)
        );
        vm.startPrank(address(1));
        ERC20(venom).approve(address(engine), 100e18);
        engine.redeemCollateralForVenom(100e18, 0);
        vm.stopPrank();
        uint256 userMinted = engine.getAmountMinted();
        uint256 userPresentVenomBalance = ERC20(venom).balanceOf(address(1));
        uint256 userPresentWethBalance = ERC20(weth).balanceOf(address(1));
        uint256 enginePresentVenomBalance = ERC20(venom).balanceOf(
            address(engine)
        );
        assertEq(userMinted, 0);
        assert(userPresentVenomBalance < userPreviousVenomBalance);
        assertEq(enginePresentVenomBalance, enginePreviousVenomBalance);
        assert(userPresentWethBalance > userPreviousWethBalance);
    }

    function testRedeemCollateralForVenomWorksWhenUserDoNotBurnTotalMinted()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
        mintedVenom
    {
        uint256 userPreviousVenomBalance = ERC20(venom).balanceOf(address(1));
        uint256 userPreviousWethBalance = ERC20(weth).balanceOf(address(1));
        uint256 enginePreviousVenomBalance = ERC20(venom).balanceOf(
            address(engine)
        );
        vm.startPrank(address(1));
        ERC20(venom).approve(address(engine), 50e18);
        engine.redeemCollateralForVenom(50e18, 0);
        vm.stopPrank();
        uint256 userMinted = engine.getAmountMinted();
        uint256 userPresentVenomBalance = ERC20(venom).balanceOf(address(1));
        uint256 userPresentWethBalance = ERC20(weth).balanceOf(address(1));
        uint256 enginePresentVenomBalance = ERC20(venom).balanceOf(
            address(engine)
        );
        assertEq(userMinted, 1);
        assert(userPresentVenomBalance < userPreviousVenomBalance);
        assertEq(enginePresentVenomBalance, enginePreviousVenomBalance);
        assert(userPresentWethBalance > userPreviousWethBalance);
    }

    function testBurnRevertWithInvalidBurnAmount()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
        mintedVenom
    {
        vm.startPrank(address(1));
        ERC20(venom).approve(address(engine), 101e18);
        vm.expectRevert();

        engine.burnVenom(101e18, 0);
        vm.stopPrank();
    }

    function testBurnWorksWithvalidBurnAmount()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
        mintedVenom
    {
        uint256 userPreviousVenomBalance = ERC20(venom).balanceOf(address(1));
        vm.startPrank(address(1));
        ERC20(venom).approve(address(engine), 90e18);

        engine.burnVenom(90e18, 0);
        vm.stopPrank();
        uint256 userPresentVenomBalance = ERC20(venom).balanceOf(address(1));
        bool mintStatus = engine.getUserMinted(address(1));
        assertEq(mintStatus, true);
        assert(userPreviousVenomBalance > userPresentVenomBalance);
    }

    function testBurnWorksWhenUserBurnsTotalAmount()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
        mintedVenom
    {
        uint256 userPreviousVenomBalance = ERC20(venom).balanceOf(address(1));
        vm.startPrank(address(1));
        ERC20(venom).approve(address(engine), 100e18);

        engine.burnVenom(100e18, 0);
        vm.stopPrank();
        uint256 userPresentVenomBalance = ERC20(venom).balanceOf(address(1));
        bool mintStatus = engine.getUserMinted(address(1));
        uint256 userMinted = engine.getAmountMinted();
        assertEq(userMinted, 0);
        assertEq(mintStatus, false);
        assert(userPreviousVenomBalance > userPresentVenomBalance);
    }

    function testCheckHealthFactorWorksIfNotDeposited()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
    {
        bool healthFactor = engine._checkHealthFactorIsGood(address(15), 1, 0);
        assertEq(healthFactor, false);
    }

    function testCheckHealthFactorWorksIfMintedUserChecksBelowThreshold()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
        mintedVenom
    {
        bool healthFactor = engine._checkHealthFactorIsGood(address(1), 1, 0);
        assertEq(healthFactor, true);
    }

    function testCheckHealthFactorWorksIfMintedUserChecksAboveThreshold()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
        mintedVenom
    {
        bool healthFactor = engine._checkHealthFactorIsGood(
            address(1),
            3000000e18,
            0
        );
        assertEq(healthFactor, false);
    }

    //////////////////////
    /// ANCESTORS TEST //
    ////////////////////

    function testCannotSetUpCollateralWithoutAncestors()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
        mintedVenom
    {
        vm.expectRevert();
        engine.setupCollateral(address(1), address(1), 160e18, 1 ether, 3e15);
    }

    function testAncestorCanSetUpCollateral()
        external
        earlyAdoptersDeposited
        userClaimedReward
        mintStateChanged
        mintedVenom
    {
      targets.push(address(engine));
      values.push(0);
      bytes memory encodedFunctionCall = abi.encodeWithSignature("setupCollateral(address,address,uint256,uint256,uint256)", address(1), address(1), 160e18, 1 ether, 3e15);
      calldatas.push(encodedFunctionCall);
      string memory description = "set up collateral";

      uint256 proposalId = ancestors.propose(targets, values, calldatas, description);
    vm.warp(block.timestamp + VOTING_DELAY + 1);
    vm.roll(block.number + VOTING_DELAY + 1);

    string memory reason = "To update collateral";
    uint8 voteway = 1;
    vm.startPrank(address(1));
    ancestors.castVoteWithReason(proposalId, voteway, reason);

    vm.warp(block.timestamp + VOTING_PERIOD + 1);
    vm.roll(block.number + VOTING_PERIOD + 1);

    bytes32 descriptionHash = keccak256(abi.encodePacked(description));
    ancestors.queue(targets, values, calldatas, descriptionHash);

    vm.warp(block.timestamp + MIN_DELAY + 1);
    vm.roll(block.number + MIN_DELAY + 1);
    ancestors.execute(targets, values, calldatas, descriptionHash);
    ( address collateralAddress,
     ,
     ,
     ,
     uint256 stabilityFee) = engine.getCollateralInfo(1);
     uint256 state = uint256(ancestors.state(proposalId)); 
     console.log(state);

    assertEq(collateralAddress, address(1));

    }
}
