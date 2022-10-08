import { MerkleTree } from 'merkletreejs';
import keccak256 from 'keccak256';

const addresses = [
    '0x5B38Da6a701c568545dCfcB03FcB875f56beddC4',
    '0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2',
    '0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db',
    '0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB',
    '0x617F2E2fD72FD9D5503197092aC168c91465E7f2',
]

const leafNodes = addresses.map(a => keccak256(a));
const tree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });

const getMerkleRoot = () => {
    return tree.getRoot().toString('hex');
}

const getAddress = (address: string) => {
    return keccak256(address);
}

const getProof = (address: string) => {
    return tree.getHexProof(getAddress(address));
}

const verify = (proof: string[], leaf: string): boolean => {
    return tree.verify(proof, getAddress(leaf), getMerkleRoot());
}

let claimAddress = addresses[1];
const claimProof = getProof(claimAddress);

// change to another address, vetify should not pass
// claimAddress = addresses[2];

console.log(`verify:`, verify(claimProof, claimAddress));