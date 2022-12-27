import { ethers } from "hardhat";

interface Order {
    tradeNo: number
    totalPay: number
    buyer: string
}

const main = async () => {
    const Fac = await ethers.getContractFactory("Eip712Demo");
    const fac = await Fac.deploy();
    await fac.deployed();

    const [owner] = await ethers.getSigners();

    const order = <Order>{
        tradeNo: 2,
        totalPay: 1000,
        buyer: await owner.getAddress(),
    };

    const domain = {
        name: 'Eip712 Demo',
        version: '1',
        chainId: await owner.getChainId(),
        verifyingContract: await fac.contractAddr(),
    };

    const types = {
        Order: [{
            name: 'tradeNo',
            type: 'uint256'
        }, {
            name: 'totalPay',
            type: 'uint256'
        }, {
            name: 'buyer',
            type: 'address'
        }]
    };
    const signature = await owner._signTypedData(domain, types, order);
    console.log(`signature:`, signature);

    const isMatch = await fac.verify(order, signature);
    console.log(`isMatch:`, isMatch);
}

main().catch(e => {
    console.error(`err:`, e);
});