// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IActivity {
    event ActivityStatusChange(address indexed owner, bytes message);
    function startActivity() external;
    function endActivity() external;

    // activity should start and not end
    function isActivityValid() external view returns (bool);
}

interface IBargain {
    event BargainForUser(address indexed from, address indexed to);
    // msg.sender start to bargin for target user
    function bargainFor(address target) external returns (bool);

    // check if msg.sender has bargined for target user or not
    function isBarginedFor(address target) external view returns (bool);

    // check if my bargain condition has been matched
    function isMyBargainConditionMatched() external view returns (bool);
}

contract NFTBargain is ERC721,  Ownable, IActivity, IBargain {
    // min bargain num, set in constractor, user can mint if this condition matched
    uint private minBargainNum;

    // storage the bagain number of user
    mapping(address => uint) bargainNum;

    // storage the bargain records
    mapping(address => mapping(address => bool)) bargainPool;

    bool isActivityStart;
    bool isActivityEnd;

    constructor(uint _bargainNum) ERC721("NFTBargain", "NBAG") {
        minBargainNum = _bargainNum;
        isActivityStart = false;
        isActivityEnd = false;
    }

    // bargain check, should not bargained, and can not bargain for self
    modifier canBargain(address target) {
        require(msg.sender != target, "cannot bargain for self");
        require(!isBarginedFor(target), "you have bargained");
        _;
    }

    // bargained number should reach the seted min number
    modifier bargainConditionShouldMatched() {
        require(isMyBargainConditionMatched(), "bargain condition not match");
        _;
    }

    // actitity should start and not end
    modifier activityShouldValid() {
        require(isActivityStart, "activity not start");
        require(!isActivityEnd, "activity has been ended");
        _;
    }

    function startActivity() public onlyOwner {
        isActivityStart = true;
        emit ActivityStatusChange(msg.sender, bytes("start activity"));
    }

    function endActivity() public onlyOwner {
        isActivityEnd = true;
        emit ActivityStatusChange(msg.sender, bytes("end activity"));
    }

    function isActivityValid() public view returns (bool) {
        return isActivityStart && !isActivityEnd;
    }

    function getSetedMinBargainNum() public view returns (uint256) {
        return minBargainNum;
    }

    function bargainFor(address target) public canBargain(target) returns (bool) {
        bargainPool[msg.sender][target] = true;
        uint256 targetBargainNum = bargainNum[target];
        bargainNum[target] = targetBargainNum + 1;
        emit BargainForUser(msg.sender, target);
        return true;
    }

    function isBarginedFor(address target) public view returns (bool) {
        require(msg.sender != target, "cannot bargain for self");
        if (bargainPool[msg.sender][target]) {
            return bargainPool[msg.sender][target];
        } else {
            return false;
        }
    }

    function isMyBargainConditionMatched() public view returns (bool) {
        return getMyBargainNum() >= minBargainNum;
    }

    function getMyBargainNum() public view returns (uint256) {
        return bargainNum[msg.sender];
    }

    function mint(uint tokenId) public activityShouldValid bargainConditionShouldMatched {
        bargainNum[msg.sender] = 0;
        _safeMint(msg.sender, tokenId);
    }
}