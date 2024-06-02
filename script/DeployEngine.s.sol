// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {Engine} from "../src/Engine.sol";
import {NetworkConfig} from "./Config/NetworkConfig.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Venom} from "../src/Venom.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Viper} from "../src/Viper.sol";
import {Ancestors} from "../src/Ancestors.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeployEngine is Script {
    address private WALLET_ADDRESS;
    Engine engine;
    NetworkConfig network;
    Venom venom;
    TimeLock timeLock;
    Viper viper;
    Ancestors ancestors;

    uint256 private constant liquidationThreshold = 150e18;
    uint256 private constant penaltyFee = 1 ether;
    uint256 private constant stabilityFee = 3e15;
    uint256 private constant totalTokenDeposited = 8000e18;
    uint256 private constant crowdSaleStartAt = 30 days;
    uint256 private constant crowdSaleDuration = 60 days;

    uint256 private constant MIN_DELAY = 7 days;
    address[] private PROPOSER_ROLE;
    address[] private EXECUTOR_ROLE;

    function run() external returns(Engine, NetworkConfig, Venom, TimeLock, Viper, Ancestors, address){
        network = new NetworkConfig();
        (
            address weth,
            address pricefeed,
            address vrfCoordinator,
            ,
            uint256 deployerKey,
            uint64 subId
        ) = network.activeNetworkConfig();

        if (block.chainid == 31337) {
            WALLET_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
            CreateSubscription createSubscription = new CreateSubscription();
            uint64 subscriptionId = createSubscription
                .createSubscriptionUsingConfig(vrfCoordinator, deployerKey);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscriptionUsingConfig(
                vrfCoordinator,
                subscriptionId,
                deployerKey
            );

            vm.startBroadcast(deployerKey);
            timeLock = new TimeLock(MIN_DELAY, PROPOSER_ROLE, EXECUTOR_ROLE);

           
            venom = new Venom();
            viper = new Viper();

            engine = new Engine(
                address(venom),
                address(viper),
                weth,
                pricefeed,
                liquidationThreshold,
                penaltyFee,
                stabilityFee,
                crowdSaleStartAt + crowdSaleDuration
            );

            ancestors = new Ancestors(viper, timeLock);

             bytes32 proposerRole = timeLock.PROPOSER_ROLE();
            bytes32 executorRole = timeLock.EXECUTOR_ROLE();
            bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

            timeLock.grantRole(proposerRole, address(ancestors));
            timeLock.grantRole(executorRole, address(0));
            timeLock.revokeRole(adminRole, WALLET_ADDRESS);

            Viper(viper).transfer(address(engine), totalTokenDeposited);
            venom.transferOwnership(address(engine));
            viper.transferOwnership(address(engine));

            engine.transferOwnership(address(timeLock));

            vm.stopBroadcast();

            AddConsumer addConsumer = new AddConsumer();
            addConsumer.addConsumerUsingConfig(
                address(engine),
                vrfCoordinator,
                deployerKey,
                subscriptionId
            );
        }

        if (block.chainid == 11155111) {
            WALLET_ADDRESS = 0xfc3c3F0d793EaC242051C98fc0DC9be60f86d964;
            vm.startBroadcast(deployerKey);
            
            timeLock = new TimeLock(MIN_DELAY, PROPOSER_ROLE, EXECUTOR_ROLE);
           
        
            venom = new Venom();
            viper = new Viper();
            engine = new Engine(
                address(venom),
                address(viper),
                weth,
                pricefeed,
                liquidationThreshold,
                penaltyFee,
                stabilityFee,
                crowdSaleStartAt + crowdSaleDuration
            );

            ancestors = new Ancestors(viper, timeLock);

             bytes32 proposerRole = timeLock.PROPOSER_ROLE();
            bytes32 executorRole = timeLock.EXECUTOR_ROLE();
            bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

            timeLock.grantRole(proposerRole, address(ancestors));
            timeLock.grantRole(executorRole, address(0));
            timeLock.revokeRole(adminRole, WALLET_ADDRESS);
            

            Viper(viper).transfer(address(engine), totalTokenDeposited);
            venom.transferOwnership(address(engine));
            viper.transferOwnership(address(engine));

            engine.transferOwnership(address(timeLock));

            vm.stopBroadcast();

            AddConsumer addConsumer = new AddConsumer();
            addConsumer.addConsumerUsingConfig(
                address(engine),
                vrfCoordinator,
                deployerKey,
                subId
            );
        }

        return (engine, network, venom, timeLock, viper, ancestors, WALLET_ADDRESS);
    }

   
}
