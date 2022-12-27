import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { expect } from "chai";

describe("Eip2612Demo", function () {
    async function deployContract() {
        const [owner, alice, bob] = await ethers.getSigners();
        const Fac = await ethers.getContractFactory("Eip2612Demo");
        const contract = await Fac.deploy();

        return { owner, alice, bob, contract };
    }

    describe("Transfer", function () {
        it("Can Mint", async function () {
            const { owner, alice, contract } = await loadFixture(deployContract);
            await contract.connect(owner).mint(await alice.getAddress(), 100);
            expect(await contract.balanceOf(await alice.getAddress())).to.eq(100);
        });

        it("Allowance Should Be 0", async function () {
            const { owner, alice, contract } = await loadFixture(deployContract);
            expect(await contract.allowance(await alice.getAddress(), contract.address)).to.eq(0);
        });

        it("Invoke by Bob with Alice's signature", async function () {
            const { owner, alice, bob, contract } = await loadFixture(deployContract);

            const permit = {
                owner: await alice.getAddress(),
                spender: contract.address,
                value: ethers.BigNumber.from("10"),
                nonce: await contract.nonces(await alice.getAddress()),
                deadline: 1672329600 // 2022-12-30
            };

            const domain = {
                name: 'Eip2612 Demo',
                version: '1',
                chainId: await owner.getChainId(),
                verifyingContract: contract.address
            };

            const types = {
                "Permit": [{
                    "name": "owner",
                    "type": "address"
                },
                {
                    "name": "spender",
                    "type": "address"
                },
                {
                    "name": "value",
                    "type": "uint256"
                },
                {
                    "name": "nonce",
                    "type": "uint256"
                },
                {
                    "name": "deadline",
                    "type": "uint256"
                }
                ]
            };

            const signature = await alice._signTypedData(domain, types, permit);
            expect(await contract.connect(bob).transferWithPermit(permit.owner, permit.spender, permit.value, permit.deadline, signature)).to.not.reverted;
        });

        it("Allowance should be correct", async function () {
            const { owner, alice, bob, contract } = await loadFixture(deployContract);

            const permit = {
                owner: await alice.getAddress(),
                spender: contract.address,
                value: ethers.BigNumber.from("10"),
                nonce: await contract.nonces(await alice.getAddress()),
                deadline: 1672329600 // 2022-12-30
            };

            const domain = {
                name: 'Eip2612 Demo',
                version: '1',
                chainId: await owner.getChainId(),
                verifyingContract: contract.address
            };

            const types = {
                "Permit": [{
                    "name": "owner",
                    "type": "address"
                },
                {
                    "name": "spender",
                    "type": "address"
                },
                {
                    "name": "value",
                    "type": "uint256"
                },
                {
                    "name": "nonce",
                    "type": "uint256"
                },
                {
                    "name": "deadline",
                    "type": "uint256"
                }
                ]
            };

            // sign by Alice 
            const signature = await alice._signTypedData(domain, types, permit);

            // invoke by Bob with Alice's signature
            await contract.connect(bob).transferWithPermit(permit.owner, permit.spender, permit.value, permit.deadline, signature);

            // check allownace
            expect(await contract.allowance(await alice.getAddress(), contract.address)).to.eq(10);
        });
    });
});