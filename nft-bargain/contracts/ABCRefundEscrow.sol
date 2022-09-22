// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ABCToken.sol";

contract ABCRefundEscrow is Ownable {
    // address of deployed ABCToken contract
    address constant ABC_TOKEN_ADDRESS = 0x9d83e140330758a8fFD07F8Bd73e86ebcA8a5692;

    mapping(address => uint256) private _deposits;

    enum State {
        Active,
        Refunding,
        Closed
    }

    State private _state;
    address payable private immutable _beneficiary;

    constructor(address payable beneficiary_) {
        require(beneficiary_ != address(0), "RefundEscrow: beneficiary is the zero address");
        _beneficiary = beneficiary_;
        _state = State.Active;
    }

    function depositsOf(address payee) public view returns (uint256) {
        return _deposits[payee];
    }

    function deposit(address payee, uint256 amount) public onlyOwner {
        require(_state == State.Active, "RefundEscrow: can only deposit while active");
        _deposits[payee] += amount;
    }

    function withdraw(address payee) public onlyOwner {
        require(_state == State.Refunding, "can only withdraw while refunding");
        uint256 payment = _deposits[payee];

        _deposits[payee] = 0;

        ABCToken(ABC_TOKEN_ADDRESS).transferFrom(address(this), payee, payment);
    }

    function close() public virtual onlyOwner {
        require(_state == State.Active || _state == State.Refunding, "RefundEscrow: can only close while active or refunding");
        _state = State.Closed;
    }

    function enableRefunds() public virtual onlyOwner {
        require(_state == State.Active, "RefundEscrow: can only enable refunds while active");
        _state = State.Refunding;
    }

    function beneficiaryWithdraw() public virtual {
        require(_state == State.Closed, "RefundEscrow: beneficiary can only withdraw while closed");
        uint256 balanceOfRest = ABCToken(ABC_TOKEN_ADDRESS).balanceOf(address(this));
        require(balanceOfRest > 0, "rest balance should greater than 0");
        
        ABCToken(ABC_TOKEN_ADDRESS).transferFrom(address(this), _beneficiary, balanceOfRest);
    }
}
