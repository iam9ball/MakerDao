// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployEngine} from "../../script/DeployEngine.s.sol";
import {Engine} from "../../src/Engine.sol";
import {NetworkConfig} from "../../script/Config/NetworkConfig.sol";
import {Venom} from "../../src/Venom.sol";
import {Viper} from "../../src/Viper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockV3Aggregator} from "../Mocks/MockV3Aggregator.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {

    //EarlyAdopters -----> No matter how much deposited, people cannot claim more than amount of token to be distributed
     DeployEngine deployer;    
    Engine engine;
    NetworkConfig network;
    Venom venom;
    Viper viper;
    Handler handler;
    address WALLET_ADDRESS;
    address pricefeed;
    address weth;

   uint256 private constant PRECISION = 1e18;
   uint256 private constant PERCENTAGE = 100;




    function setUp() external {
         deployer = new DeployEngine();
         (engine, network, venom, , viper, , WALLET_ADDRESS) = deployer.run();
          (weth,  pricefeed, , , , ) = network.activeNetworkConfig();
          handler = new Handler(engine, network, viper, venom, WALLET_ADDRESS); 
          targetContract(address(handler));

        
    }

    function invariant_earlyAdoptersCannotHaveMoreTokenClaimedThanAmountToDistribute() external view {
         uint256 totalDeposited = engine.getTotalDeposited();
         uint256 totalAmountToClaim = engine.tokenToTransfer(totalDeposited);
         uint256 earlyAdoptersTokenToTransfer = engine.getTotalTokenToTransfer();
         assert(earlyAdoptersTokenToTransfer >= totalAmountToClaim);
    }
    
    
    function invariant_engineCollateralBalanceMustBeGreaterThanVenom() external view {
       uint256 totalEngineWethBalance = ERC20(weth).balanceOf(address(engine));
       uint256  totalEngineWethValue = engine.getUsdValue(totalEngineWethBalance, pricefeed);
       uint256 totalVenomBalance =  ERC20(venom).totalSupply();
       console.log(totalVenomBalance);
        console.log(totalVenomBalance);
         console.log(totalVenomBalance);
          console.log(totalVenomBalance);
          if (totalVenomBalance == 0) {
               return;
          }
     uint256 expectedWethToVenomRatio = (totalEngineWethValue * PRECISION) /  totalVenomBalance;
     console.log(expectedWethToVenomRatio);
          console.log(expectedWethToVenomRatio);
     console.log(expectedWethToVenomRatio);

       uint256 collateralThreshold = (engine.getThreshold(0)) / 100;
       console.log(collateralThreshold);

       assert(expectedWethToVenomRatio >= collateralThreshold);
    }

}