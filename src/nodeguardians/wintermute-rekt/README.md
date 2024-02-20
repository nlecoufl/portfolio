# WINTERMUTE - REKT
Based on the 2022 Wintermute hack from the Rekt Leaderboard. [Rekt Leaderboard](https://rekt.news/leaderboard/). 

## Overview

"Dead addresses" are vanity addresses that start with 0x0dead. LADY_WHITEFROST `0x0DEaD582fa84de81e5287132d70d9a296224Cf90`, for instance, is such a dead address.

These addresses have been generated using a custom address generator. This generator can be found in [`necromancy-spells/`](necromancy-spells/).

### Install dependencies
```
cd src/nodeguardians/wintermute-rekt && pnpm install
```

The goal is to break:
```solidity
contract UndeadHorde {

    address public constant LADY_WHITEFROST 
        = 0x0DEaD582fa84de81e5287132d70d9a296224Cf90;

    bool public isActive = true;
    mapping(address => bool) public infested;

    function infestDead(address _target) external {
        require(isActive);
        require(_fromLady(), "We only answer to our Queen Mother...");
        require(_isDead(_target), "Target is still alive...");

        infested[_target] = true;
    }

		// So we have to find a way to call this function
		// The only possible way to do so is by being LADY_WHITEFROST
		// So we have to find the private key associated with her address
    function releaseArmy() external {
        require(_fromLady(), "We only answer to our Queen Mother...");
        isActive = false;
    }

    function _fromLady() private view returns (bool) {
        return msg.sender == LADY_WHITEFROST;
    }

    function _isDead(address _target) private pure returns (bool) {
        uint160 prefix = uint160(_target) >> 140;
        return prefix == 0x0dead;
    }

}
```

## Deployments (Sepolia)
| Contract        | Address      |
| ------|-----|
| UndeadHorde  	| [0xAb73332D226a75f81B3110A3c56EccBb70FFEFF8](https://sepolia.etherscan.io/address/0xAb73332D226a75f81B3110A3c56EccBb70FFEFF8)	| 

## Walkthrough

We notice in the [`find-more-dead.js`](necromancy-spells/find-more-dead.js) script that the seed is only 16 bytes:
```
const { BigNumber } = require("ethers");
const { arrayify, keccak256, zeroPad } = require("ethers/lib/utils");
const { Worker } = require('worker_threads');
const { CURVE } = require('@noble/secp256k1');

const MAX_UINT16 = 65535;
const NUM_OF_THREADS = 3;
const K = "0xc01ddeadc01ddeadc01ddead"

// Generate a random private key `p`
const seed = Math.floor(Math.random() * MAX_UINT16);
const privateKey = BigNumber.from(keccak256(seed));

console.log(`Seed: ${seed}`);

// Start threads running `find-dead.js`
for (let i = 0; i < NUM_OF_THREADS; i++) {

  // Each thread is given a private key `p + (i * K)`
  const delta = BigNumber.from(K).mul(i);
  const seedKey = zeroPad(arrayify(privateKey.add(delta).mod(CURVE.n)), 32);

  const thread = new Worker(
    "./find-dead.js", 
    { workerData: { seedKey: seedKey }}
  );

  thread.on('message', (msg) => {
    console.log(msg);
  });
  
}
```

This means that this generator, along with its number `N=3` of threads, is generating only `3 * 2**16 = 3 * 65536 = 196608` different private keys, which is a reasonable among of keys to compute.

### Step 1
We can compute those private along with their public keys using [`create-pubkeys.js`](necromancy-spells/create-pubkeys.js) into a .json file `pubkeys.json` as an array of object like this one: 
```
{"04b793ec11629accadfd51835c82654391fad3f7489af36440155403e366dc677808fa587ed7576c1274e4fcdf886789b72b52de5e1eed3907500d9d4d3f8aa1fb": [188,54,120,158,122,30,40,20,54,70,66,41,130,143,129,125,102,18,247,180,119,214,101,145,255,150,169,224,100,188,201,138]}
```

### Step 2 
The idea is to retrieve the public key used from a previous transaction on-chain. We can use [`find-publickey.js`](necromancy-spells/find-publickey.js) for that:
```javascript
const ethers = require("ethers");

const getPublicKeyFromTransactionID = async (hash) => {
    const provider = new ethers.providers.JsonRpcProvider(`https://ethereum-sepolia.publicnode.com`);
    const transactionHash = await provider.getTransaction(hash);

    const expandedSig = {
        r: transactionHash.r,
        s: transactionHash.s,
        v: transactionHash.v
    }

    const signature = ethers.utils.joinSignature(expandedSig);

    let transactionHashData;
    switch (transactionHash.type) {
        case 0:
            transactionHashData = {
                gasPrice: transactionHash.gasPrice,
                gasLimit: transactionHash.gasLimit,
                value: transactionHash.value,
                nonce: transactionHash.nonce,
                data: transactionHash.data,
                chainId: transactionHash.chainId,
                to: transactionHash.to
            };
            break;
        case 2:
            transactionHashData = {
                gasLimit: transactionHash.gasLimit,
                value: transactionHash.value,
                nonce: transactionHash.nonce,
                data: transactionHash.data,
                chainId: transactionHash.chainId,
                to: transactionHash.to,
                type: 2,
                maxFeePerGas: transactionHash.maxFeePerGas,
                maxPriorityFeePerGas: transactionHash.maxPriorityFeePerGas
            }
            break;
        default:
            throw "Unsupported transactionHash type";
    }
    const rstransactionHash = await ethers.utils.resolveProperties(transactionHashData)
    const raw = ethers.utils.serializeTransaction(rstransactionHash) // returns RLP encoded transactionHash

    const msgHash = ethers.utils.keccak256(raw) // as specified by ECDSA
    const msgBytes = ethers.utils.arrayify(msgHash) // create binary hash
    const recoveredPubKey = ethers.utils.recoverPublicKey(msgBytes, signature)
    // const newAddress = hexDataSlice(keccak256(
    //     hexDataSlice(recoveredPubKey, 1)
    // ), 12);
    console.log(recoveredPubKey)
    return recoveredPubKey
}

getPublicKeyFromTransactionID("0x9a209b3ce7dd07a5b789aa6fcc998c4bb2f5e0aff3522a08d60b18c142c071ef")
```

Which gives 
```sh
0x04077029792b56144069fac2787ca35fad37f7f0634236ba02e307bff5a2f120e1c1484a687dc468e671eef339d1437d02d51949973ccfd29f33efe9aa4b9a6017
```

### Step 3
After step 1 and 2, we have everything set. 
On the below script, we are decrementing $P$ (i.e. $P \leftarrow P - G$ ) until we find a public key that is equal to one in `pubkeys.json`.
```javascript
const { BigNumber } = require("ethers");
const { Point } = require('@noble/secp256k1');

var fs = require('fs');
fs.readFile('pubkeys.json', function (err, content) {
    if (err) throw err;
    var obj = JSON.parse(content);

    let newPoint = Point.fromHex(
        "04077029792b56144069fac2787ca35fad37f7f0634236ba02e307bff5a2f120e1c1484a687dc468e671eef339d1437d02d51949973ccfd29f33efe9aa4b9a6017",
    );

    for (let i = 1; ; i++) {
        newPoint = newPoint.subtract(Point.BASE);
        const hexNewPoint = newPoint.toHex();

        if (obj[hexNewPoint] !== undefined) {
            const deadKey = BigNumber.from(obj[hexNewPoint]).add(i);
            console.log(
                `\nPrivate Key: ${deadKey.toHexString()}\
                \nPublic Key: ${hexNewPoint}`
            )

            break;
        }
    }
})
```

### Step 4
Release the horde by calling `undeadHorde.releaseArmy()` in the [`Activate.s.sol`](scripts/Activate.s.sol) scripts using this private key.