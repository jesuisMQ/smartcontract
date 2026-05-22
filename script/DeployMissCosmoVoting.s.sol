// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {MissCosmoVoting} from "src/MissCosmoVoting.sol";


contract DeployMissCosmoVoting is Script {
    MissCosmoVoting misscosmovoting;

    function run() external returns (MissCosmoVoting) {

        vm.startBroadcast();
        misscosmovoting = new MissCosmoVoting(address(0x694AA1769357215DE4FAC081bf1f309aDC325306));
        vm.stopBroadcast();

        return (misscosmovoting);
    }
}