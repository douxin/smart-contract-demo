// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TRefundEscrow.sol";

contract ABCRefundEscrow is Ownable, TRefundEscrow {
    // address of deployed ABCToken contract
    address constant ABC_TOKEN_ADDRESS =
        0x9d83e140330758a8fFD07F8Bd73e86ebcA8a5692;

    IERC20 private _token;

    constructor(address payable beneficiary_) TRefundEscrow(beneficiary_) {
        _token = IERC20(ABC_TOKEN_ADDRESS);
    }

    function deposit(address payee, uint256 amount)
        public
        payable
        override
        onlyOwner
    {
        super.deposit(payee, amount);
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
        require(balanceOfRest > 0, "rest balance should greater than 0");

        _token.transferFrom(address(this), beneficiary(), balanceOfRest);
    }
}
