import { ethers } from "hardhat";

async function main() {
    const MIN_BARGAIN_NUM = 2;
    const Bargain = await ethers.getContractFactory("NFTBargain");
    const bargain = await Bargain.deploy(MIN_BARGAIN_NUM);
    await bargain.deployed();

    console.log(`deployed NFTBargain contract with min bargain number set to ${MIN_BARGAIN_NUM}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
