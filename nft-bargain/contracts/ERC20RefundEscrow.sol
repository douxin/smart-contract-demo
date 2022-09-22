// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RefundEscrow.sol";

contract ERC20RefundEscrow is Ownable, RefundEscrow {
    // address of deployed ABCToken contract
    address constant ABC_TOKEN_ADDRESS =
        0x9d83e140330758a8fFD07F8Bd73e86ebcA8a5692;

    IERC20 private _token;

    constructor(address payable beneficiary_) RefundEscrow(beneficiary_) {
        _token = IERC20(ABC_TOKEN_ADDRESS);
    }

    function withdraw(address payable payee) public override {
        require(
            state() == State.Refunding,
            "can only withdraw while refunding"
        );
        uint256 payment = depositsOf(payee);

        emptyDeposit(payee);

        _token.transferFrom(address(this), payee, payment);
    }

    function beneficiaryWithdraw() public override {
        require(
            state() == State.Closed,
            "RefundEscrow: beneficiary can only withdraw while closed"
        );
        uint256 balanceOfRest = _token.balanceOf(address(this));
        _token.transferFrom(address(this), beneficiary(), balanceOfRest);
    }
}
