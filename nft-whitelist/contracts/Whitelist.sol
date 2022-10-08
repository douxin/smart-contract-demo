// SPDX-License-Identifier: MIT
// 本合约仅实现白名单功能，并未实现 NFT 相关接口
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Whitelist is Ownable {
    bytes32 private _root;
    mapping(address => bool) private _claims;

    function setRoot(bytes32 root) public onlyOwner {
        _root = root;
    }

    function getRoot() public view returns (bytes32) {
        return _root;
    }

    function isValid(address user, bytes32[] calldata proof) private view returns (bool) {
        return MerkleProof.verify(proof, _root, keccak256(abi.encodePacked(user)));
    }

    function isMinted(address user) private view returns (bool) {
        return _claims[user];
    }

    function mint(bytes32[] calldata proof) external returns (uint256) {
        require(isValid(msg.sender, proof), "not int whitelist");
        require(!isMinted(msg.sender), "minted");
        _claims[msg.sender] = true;
        return 1; // 省略 mint 流程
    }
}