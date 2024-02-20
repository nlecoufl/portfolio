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


