// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {NetworkConfig} from "./Config/NetworkConfig.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run() external returns (uint64) {
        NetworkConfig network = new NetworkConfig();
        ( , , address vrfCoordinator, , uint256 deployerKey,  ) = network
            .activeNetworkConfig();
        return createSubscriptionUsingConfig(vrfCoordinator, deployerKey);
    }

   


    function createSubscriptionUsingConfig(
        address _vrfCoordinator,
        uint256 _deployerKey
    ) public returns (uint64) {
        vm.startBroadcast(_deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        return subId;
    }
}

contract FundSubscription is Script {
    uint96 private constant FUND_AMOUNT = 3 ether;

    address vrfCoordinator;
    uint256 deployerKey;
    uint64 subId;

    function run() external {
        NetworkConfig network = new NetworkConfig();
        (, , vrfCoordinator, , deployerKey, subId) = network
            .activeNetworkConfig();
        fundSubscriptionUsingConfig(vrfCoordinator, subId, deployerKey);
    }

    function fundSubscriptionUsingConfig(
        address _vrfCoordinator,
        uint64 _subId,
        uint256 _deployerKey
    ) public {
        vm.startBroadcast(_deployerKey);
        VRFCoordinatorV2Mock(_vrfCoordinator).fundSubscription(
            _subId,
            FUND_AMOUNT
        );
        vm.stopBroadcast();
    }
}

contract AddConsumer is Script {
    function run() external {
        NetworkConfig network = new NetworkConfig();
        (
            
            
            ,
            ,
            address vrfCoordinator,
            ,
            uint256 deployerKey,
            uint64 subId
        ) = network.activeNetworkConfig();
        address Engine = DevOpsTools.get_most_recent_deployment(
            "Engine",
            block.chainid
        );
        addConsumerUsingConfig(Engine, vrfCoordinator, deployerKey, subId);
    }

    function addConsumerUsingConfig(
        address _Engine,
        address _vrfCoordinator,
        uint256 _deployerKey,
        uint64 _subId
    ) public {
        vm.startBroadcast(_deployerKey);
        VRFCoordinatorV2Mock(_vrfCoordinator).addConsumer(_subId, _Engine);
        vm.stopBroadcast();
    }
}
