// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "./RefundEscrow.sol";

contract ETHRefundEscrow is RefundEscrow {
    using Address for address payable;

    constructor(address payable beneficiary_) RefundEscrow(beneficiary_) {
    }

    function deposit(address payee, uint256 amount) public payable override onlyOwner {
        uint256 _amount = msg.value;
        super.deposit(payee, _amount);
    }

    function withdraw(address payable payee) public override {
        require(
            state() == State.Refunding,
            "can only withdraw while refunding"
        );
        uint256 payment = depositsOf(payee);

        emptyDeposit(payee);

        payee.sendValue(payment);
    }

    function beneficiaryWithdraw() public override {
        require(state() == State.Closed, "RefundEscrow: beneficiary can only withdraw while closed");
        beneficiary().sendValue(address(this).balance);
    }
}