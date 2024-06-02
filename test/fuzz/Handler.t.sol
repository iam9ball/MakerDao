// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../../src/Engine.sol";
import {NetworkConfig} from "../../script/Config/NetworkConfig.sol";
import {Viper} from "../../src/Viper.sol";
import {Venom} from "../../src/Venom.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {WETH} from "../../src/weth.sol";



contract Handler is Test{

    Engine private immutable i_engine;
    NetworkConfig private immutable i_network;
    Viper private immutable i_viper;
    Venom private immutable i_venom;
    address private immutable i_wallet;
    address weth;
    address pricefeed;
    address WALLET_ADDRESS;
    uint256 private constant MAX_MINT_AMOUNT = type(uint96).max;
     uint256 private constant INDEX = 0;
     uint256 private constant PRECISION = 1e18;
     uint256 private constant PERCENTAGE = 100;


    constructor(Engine _engine, NetworkConfig _network, Viper _viper, Venom _venom, address _wallet) {
       i_engine = _engine;
       i_network = _network;
       i_viper = _viper;
       i_venom = _venom;
       i_wallet = _wallet;
        (weth, pricefeed, , , , ) = _network.activeNetworkConfig();
    }


    function earlyAdoptersDeposit(uint256 _amount, uint256 caller) external {
        uint256 endTime = i_engine.getEarlyAdoptersEndTime();
        if (block.timestamp > endTime) {
            return;
        }
        uint256 totalDeposited = i_engine.getTotalDeposited();
         uint256 tokenToTransfer = i_engine.getTotalTokenToTransfer();
       
        caller = bound(caller, 1, 14);
        
        uint256 userDepositedBalance = i_engine.getUserDepositBalance(address(uint160(caller)));
        uint256 maxDepositAmount = 300e18 - userDepositedBalance;
        uint256 minDepositAmount = 30e18;
       
       
        if (maxDepositAmount < minDepositAmount) {
            return;
        }
        uint256 depositAmount = bound(_amount, minDepositAmount, maxDepositAmount);
        mintDepositors(depositAmount);
         if (totalDeposited + depositAmount > tokenToTransfer) {
            return;
         }
         
         
        vm.startPrank(address(uint160(caller)));
        ERC20(weth).approve(address(i_engine), depositAmount);
        i_engine.deposit(address(uint160(caller)), depositAmount);
        vm.stopPrank();

    }


    function mintDepositors(uint256 _amount) internal {
       
        for (uint160 i = 1; i < 15; i++) {
            vm.startPrank(i_wallet);
             WETH(weth).mint(address(i), _amount);
             vm.stopPrank();
           
            
        }

    }

    function engineDepositCollateral(uint256 _amount, uint256 caller) external {
        caller = bound(caller, 1, 14);
       
        _amount = bound(_amount, 1, MAX_MINT_AMOUNT);
         mintDepositors(_amount);
         vm.startPrank(address(uint160(caller)));
          ERC20(weth).approve(address(i_engine), _amount);
           i_engine.depositCollateral(address(uint160(caller)), INDEX, _amount);
         vm.stopPrank();

    }

    function engineMintVenom(uint256 _time, uint256 caller, uint256 _amount) external {
         caller = bound(caller, 1, 14);
       uint256 engineStart = i_engine.getEngineStartAt();
       uint256 maxStartAt = type(uint32).max;
       _time = bound(_time, engineStart, maxStartAt);
        vm.warp(block.timestamp + _time);
       vm.roll(block.number + (_time)/ 10); 
       i_engine.performUpkeep("");
       uint256 userCollateralInUsd = i_engine.getCollateralInUsd(address(uint160(caller)), INDEX);
       uint256 userMintedBalance = i_engine.getUserMintedBalance(address(uint160(caller)), INDEX);
       uint256 collateralThreshold = i_engine.getThreshold(INDEX);
        if (userCollateralInUsd == 0) {
        return;
       }
       uint256 maxAmountToMint = ((userCollateralInUsd * PRECISION) / (collateralThreshold  / PERCENTAGE));
      

        _amount = bound(_amount, 1, maxAmountToMint);
        if (userMintedBalance + _amount > 10000e18) {
            return;
        }
       
       
      
       bool healthFactor = i_engine._checkHealthFactorIsGood(address(uint160(caller)), _amount, INDEX);
       if (healthFactor == false) {
        return;
       }
        vm.startPrank(address(uint160(caller)));
        
      
        i_engine.mint(_amount, INDEX);
          console.log("yes");
        vm.stopPrank();
       


    }

    // There is a need to be a bound after user has minted -> Because the amount allowed to redeem would gradually reduce as more gets minted
    // This is a known issue to be fixed !!!!! 
    function engineRedeemCollateral(uint256 _amount, uint256 caller ) external {
        uint256 collateralThreshold = i_engine.getThreshold(INDEX);
        caller  = bound(caller, 1, 14);
         uint256 userDepositBalance = i_engine.getUserCollateralBalance(address(uint160(caller)), INDEX);
         bool userMinted = i_engine.getUserMinted(address(uint160(caller)));
         if (userMinted == true || userDepositBalance == 0) {
            return;
         }
        
         _amount = bound(_amount, 1,  userDepositBalance);
         uint256 userHealthFactor = i_engine.calculateHealthFactor(address(uint160(caller)), _amount, INDEX);
         if (userHealthFactor < collateralThreshold) {
            return;
         }
        
        vm.startPrank(address(uint160(caller)));
        i_engine.redeemCollateral(INDEX, _amount);
        vm.stopPrank();

    }
}