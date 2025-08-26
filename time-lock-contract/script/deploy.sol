// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TimeLockVaultFactory.sol";

contract DeployFactoryScript is Script {
    function run() external {
        vm.startBroadcast();
        // Deploy the TimeLockVaultFactory contract, owner = msg.sender
        new TimeLockVaultFactory(address(0));
        vm.stopBroadcast();
    }
}