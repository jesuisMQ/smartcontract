// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployMissCosmoVoting} from "script/DeployMissCosmoVoting.s.sol";
import {MissCosmoVoting} from "src/MissCosmoVoting.sol";
import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DeployMissCosmoVotingTest is Test {

    string RPC = vm.envString("SEPOLIA_RPC_URL");

    DeployMissCosmoVoting deployer;
    MissCosmoVoting voting;

    address constant FEED =
        0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function setUp() public {

        vm.createSelectFork(RPC);

        deployer = new DeployMissCosmoVoting();
    }

    function testDeployScriptWorks() public {
    voting = deployer.run();

    address expectedOwner =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    assertEq(voting.owner(), expectedOwner);

    assertEq(
        address(voting.priceFeed()),
        FEED
    );
}

    function testPriceFeedWorks() public {

        voting = deployer.run();

        uint256 ethPrice = voting.getEthPrice();

        assertGt(ethPrice, 1000e18);
    }

    function testPackagesInitialized() public {

        voting = deployer.run();

        (
            uint256 usdPrice,
            uint256 votes
        ) = voting.packages(0);

        assertEq(usdPrice, 1e18);
        assertEq(votes, 5);
    }
}