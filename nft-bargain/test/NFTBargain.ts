import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import { expect } from 'chai';

const MIN_BARGAIN_NUM = 1;

describe('NFTBargain', () => {
    const deployedFixture = async () => {
        const [owner, otherAccount] = await ethers.getSigners();

        const Bargain = await ethers.getContractFactory("NFTBargain");
        const bargain = await Bargain.deploy(MIN_BARGAIN_NUM);

        return { owner, otherAccount, bargain };
    }

    describe('Deployment', () => {
        it('Should set to right min bargain numer', async () => {
            const { bargain } = await loadFixture(deployedFixture);
            expect(await bargain.getSetedMinBargainNum()).to.eq(MIN_BARGAIN_NUM);
        })

        it('Activity should not valid', async () => {
            const { bargain } = await loadFixture(deployedFixture);
            expect(await bargain.isActivityValid()).to.false;
        })
    })

    describe('Activity', () => {
        it('Should valid after start', async () => {
            const { bargain } = await loadFixture(deployedFixture);
            await bargain.startActivity();
            expect(await bargain.isActivityValid()).to.true;
        })

        it('Should invalid after end activty', async () => {
            const { bargain } = await loadFixture(deployedFixture);
            await bargain.endActivity();
            expect(await bargain.isActivityValid()).to.false;
        })
    })

    describe('Bargain', () => {
        it('Should not bargain if activity not start', async () => {
            const {bargain, otherAccount} = await loadFixture(deployedFixture);
            await expect(bargain.bargainFor(otherAccount.address)).to.be.revertedWith('activity not start');
        })

        it('Should not bargain if activity has been ended', async () => {
            const {bargain, otherAccount} = await loadFixture(deployedFixture);
            await bargain.startActivity();
            await bargain.endActivity();
            await expect(bargain.bargainFor(otherAccount.address)).to.be.revertedWith('activity has been ended');
        })

        it('Should not bargain for self', async () => {
            const {bargain, owner} = await loadFixture(deployedFixture);
            await bargain.startActivity();
            await expect(bargain.bargainFor(owner.address)).to.be.revertedWith('cannot bargain for self');
        })

        it('Should not revert if bargin for other address first time', async () => {
            const {bargain, otherAccount} = await loadFixture(deployedFixture);
            await bargain.startActivity();
            await expect(bargain.bargainFor(otherAccount.address)).not.to.be.reverted;
        })

        it('Should only bargain once', async () => {
            const {bargain, otherAccount} = await loadFixture(deployedFixture);
            await bargain.startActivity();
            await bargain.bargainFor(otherAccount.address);
            await expect(bargain.bargainFor(otherAccount.address)).to.be.revertedWith('you have bargained');
        })
    })

    describe('Mint', () => {
        it('Should revert if activity not start', async () => {
            const { bargain } = await loadFixture(deployedFixture);
            await expect(bargain.mint(1)).to.be.revertedWith('activity not start');
        })

        it('Should revert if activity has been ended', async () => {
            const {bargain} = await loadFixture(deployedFixture);
            await bargain.startActivity();
            await bargain.endActivity();
            await expect(bargain.mint(1)).to.be.revertedWith('activity has been ended');
        })

        it('Should revert if bargain condition not matched', async () => {
            const {bargain} = await loadFixture(deployedFixture);
            await bargain.startActivity();
            await expect(bargain.mint(1)).to.be.revertedWith('bargain condition not match');
        })

        it('Should mint success if all conditions reached', async () => {
            const {bargain, otherAccount} = await loadFixture(deployedFixture);
            await bargain.startActivity();
            await bargain.bargainFor(otherAccount.address);
            expect(await bargain.connect(otherAccount).mint(1)).not.to.be.reverted;
        })

        it('Bargain number should set to 0 after mint success', async () => {
            const {bargain, otherAccount} = await loadFixture(deployedFixture);
            await bargain.startActivity();
            await bargain.bargainFor(otherAccount.address);
            await bargain.connect(otherAccount).mint(1);
            expect(await bargain.connect(otherAccount).getMyBargainNum()).to.be.eq(0);
        })
    })
})