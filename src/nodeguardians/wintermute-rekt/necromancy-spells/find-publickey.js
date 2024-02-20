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