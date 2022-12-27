import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { expect } from "chai";

interface Order {
    tradeNo: number
    totalPay: number
    buyer: string
}

describe("Eip712Demo", function () {
    async function deployContract() {
        const [owner, other] = await ethers.getSigners();
        const Fac = await ethers.getContractFactory("Eip712Demo");
        const contract = await Fac.deploy();

        return { owner, other, contract };
    }

    describe("VerifySignature", function () {
        it("Should Match", async function () {
            const { owner, contract } = await loadFixture(deployContract);

            const order = <Order>{
                tradeNo: 2,
                totalPay: 1000,
                buyer: await owner.getAddress(),
            };

            const domain = {
                name: 'Eip712 Demo',
                version: '1',
                chainId: await owner.getChainId(),
                verifyingContract: await contract.contractAddr(),
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
            const isMatch = await contract.verify(order, signature);
            expect(isMatch).to.be.true;
        });

        it("Should Not Match", async function () {
            const { owner, contract } = await loadFixture(deployContract);

            const order = <Order>{
                tradeNo: 2,
                totalPay: 1000,
                buyer: await owner.getAddress(),
            };

            const domain = {
                name: 'Eip712 Demo',
                version: '1',
                chainId: await owner.getChainId(),
                verifyingContract: await contract.contractAddr(),
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

            // change tradeNo after signed
            order.tradeNo = 3;
            const isMatch = await contract.verify(order, signature);
            // sig should not match
            expect(isMatch).to.be.false;
        });
    });
});