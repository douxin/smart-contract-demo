// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IEip2612 {
    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

contract Eip2612Demo is ERC20, IEip2612, Ownable {
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 private DOMAIN_SEPARATOR_;

    using Counters for Counters.Counter;
    mapping(address => Counters.Counter) nonces_;

    constructor() ERC20("Eip2612 Demo", "E2612") {
        DOMAIN_SEPARATOR_ = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes("Eip2612 Demo")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "Invalid address");
        _mint(to, amount);
    }

    function nonceOf(address to) public returns (uint256) {
        uint256 current = nonces_[to].current();
        nonces_[to].increment();
        return current;
    }

    function transferWithPermit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        bytes memory signature
    ) external {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return permit(owner, spender, value, deadline, v, r, s);
    }

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        bytes32 hashedPermit = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonceOf(owner),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR_, hashedPermit)
        );

        address signer = ecrecover(digest, v, r, s);

        require(signer == owner, "Invalid Signature");
        _approve(owner, spender, value);
    }

    function nonces(address owner) external view override returns (uint) {
        return nonces_[owner].current();
    }

    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return DOMAIN_SEPARATOR_;
    }
}
