// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Eip712Demo {
    struct Order {
        uint256 tradeNo;
        uint256 totalPay;
        address buyer;
    }

    string public constant name = "Eip712 Demo";
    string public constant version = "1";

    bytes32 constant ORDER_TYPEHASH =
        keccak256("Order(uint256 tradeNo,uint256 totalPay,address buyer)");
    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 private DOMAIN_SEPARATOR;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    function contractAddr() public view returns (address) {
        return address(this);
    }

    function hashOrder(Order memory order_) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order_.tradeNo,
                    order_.totalPay,
                    order_.buyer
                )
            );
    }

    function verify(Order memory order_, bytes memory signature) public view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked(
            '\x19\x01',
            DOMAIN_SEPARATOR,
            hashOrder(order_)
        ));

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return ecrecover(digest, v, r, s) == msg.sender;
    }
}
