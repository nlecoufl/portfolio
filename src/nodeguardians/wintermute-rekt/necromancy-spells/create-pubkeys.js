const { BigNumber } = require("ethers");
const { keccak256, arrayify, zeroPad } = require("ethers/lib/utils");
const { Point, CURVE } = require('@noble/secp256k1');
var fs = require('fs');

const MAX_UINT16 = 65535;
const NUM_OF_THREADS = 3;
const K = "0xc01ddeadc01ddeadc01ddead"

fs.appendFile("pubkeys.json", "{", (err) => {
    if (err) {
        console.log(err);
    }

});

for (let j=0; j < NUM_OF_THREADS; j++){
    for (let i = 0; i < MAX_UINT16; i++) {
        const seed = i;
        const privateKey = BigNumber.from(keccak256(seed));
        const delta = BigNumber.from(K).mul(j);
        const seedKey = zeroPad(arrayify(privateKey.add(delta).mod(CURVE.n)), 32);

        let newPoint = Point.fromPrivateKey(seedKey);
    
        const toAppend = `"${newPoint.toHex()}": [${seedKey}]`;
        const comma = (j===NUM_OF_THREADS-1 && i===MAX_UINT16-1) ? "" : ",";
        fs.appendFile("pubkeys.json", toAppend+comma, (err) => {
            if (err) {
                console.log(err);
            }
        });
    }
}

fs.appendFile("pubkeys.json", "}", (err) => {
    if (err) {
        console.log(err);
    }
});