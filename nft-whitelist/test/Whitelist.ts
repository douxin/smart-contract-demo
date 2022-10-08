import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import { expect } from 'chai';
import keccak256 from 'keccak256';
import { MerkleTree } from 'merkletreejs';

describe('Whitelist', () => {
    const deployedFixture = async () => {
        const signers = await ethers.getSigners();
        const owner = signers[0];

        const addresses: string[] = [];
        for (const signer of signers) {
            const addr = await signer.getAddress();
            addresses.push(addr);
        }

        const leafs = addresses.map(addr => {
            return keccak256(addr);
        });
        const tree = new MerkleTree(leafs, keccak256, { sortPairs: true });

        const Whitelist = await ethers.getContractFactory('Whitelist');
        const whitelist = await Whitelist.deploy();

        return { owner, whitelist, signers, addresses, tree }
    }

    describe('merkle tree', () => {
        it('set root', async () => {
            const { addresses, whitelist, tree } = await loadFixture(deployedFixture);

            const root = tree.getHexRoot();
            await whitelist.setRoot(root);

            expect(await whitelist.getRoot()).to.eq(root);
        })

        it('address in whitelist can mint', async () => {
            const { signers, addresses, whitelist, tree } = await loadFixture(deployedFixture);

            const root = tree.getHexRoot();
            await whitelist.setRoot(root);

            const targetUser = signers[1];
            const targetUserAddrStr = await targetUser.getAddress();

            const proof = tree.getHexProof(keccak256(targetUserAddrStr));
            expect(await whitelist.connect(targetUser).mint(proof)).not.to.be.reverted;
        })

        it('address not in whitelist cannot mint', async () => {
            const { signers, addresses, whitelist, tree } = await loadFixture(deployedFixture);

            const root = tree.getHexRoot();
            await whitelist.setRoot(root);

            const targetUser = signers[1];
            const targetUserAddrStr = await targetUser.getAddress();
            const proof = tree.getHexProof(keccak256(targetUserAddrStr));

            const caller = signers[2];
            await expect(whitelist.connect(caller).mint(proof)).to.be.revertedWith('not int whitelist');
        })

        it('address cannot mint after minted', async () => {
            const { signers, addresses, whitelist, tree } = await loadFixture(deployedFixture);

            const root = tree.getHexRoot();
            await whitelist.setRoot(root);

            const targetUser = signers[1];
            const targetUserAddrStr = await targetUser.getAddress();
            const proof = tree.getHexProof(keccak256(targetUserAddrStr));
            await whitelist.connect(targetUser).mint(proof);
            await expect(whitelist.connect(targetUser).mint(proof)).to.be.revertedWith('minted');
        })
    })
})