// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {Script} from "forge-std/Script.sol";
import {Auction} from "../src/Auction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";



contract DeployAuction is Script {

     
    

     function run (uint256 _duration,  
                   address _collateral, 
                    uint256 _amount,  
                    address _engine,  
                    uint256 _startingPrice,   
                    uint256 _discountRate,   
                    address _venom) external returns (address) {
            vm.startBroadcast();
             Auction auction = new Auction(_duration,  _collateral,  _amount,  _engine, _startingPrice,  _discountRate, _venom);
             vm.stopBroadcast();
          return address(auction);

     }

    
}