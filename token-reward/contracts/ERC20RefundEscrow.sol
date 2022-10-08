// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RefundEscrow.sol";

contract ERC20RefundEscrow is Ownable, RefundEscrow {
    IERC20 private _token;

    constructor(address payable beneficiary_, address contractAddress) RefundEscrow(beneficiary_) {
        _token = IERC20(contractAddress);
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
