// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "../contracts/UndeadHorde.sol";

contract ActivateScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public  {
        vm.startBroadcast(deployerPrivateKey);
        UndeadHorde undeadHorde = UndeadHorde(0xAb73332D226a75f81B3110A3c56EccBb70FFEFF8);

        undeadHorde.releaseArmy();
        vm.stopBroadcast();
    }
}