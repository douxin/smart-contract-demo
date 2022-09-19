// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

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
    function isBargainedFor(address target) external view returns (bool);

    // check if my bargain condition has been matched
    function isMyBargainConditionMatched() external view returns (bool);
}

contract NFTBargain is ERC721, Ownable, IActivity, IBargain {
    // min bargain num, set in constractor, user can mint if this condition matched
    uint256 private _minBargainNum;

    uint256 private _maxSupplyNum;
    uint256 private _currentSuppliedNum;
    uint256 private _maxMintNumPerAddress;

    // storage the bagain number of user
    mapping(address => uint256) bargainNums;

    // storage the bargain records
    mapping(address => mapping(address => bool)) bargainPool;

    bool _isActivityValid;

    struct TokenProperty {
        uint256 bargainNum;
    }

    struct TokenURI {
        bytes32 imageUrl;
        TokenProperty properties;
    }

    mapping(uint256 => TokenURI) tokenUris;

    using Counters for Counters.Counter;
    Counters.Counter private tokenId;

    constructor(uint256 minBargainNum, uint256 maxSupply, uint256 maxMintNumPerAddress) ERC721("NFTBargain", "NBAG") {
        _minBargainNum = minBargainNum;
        _maxSupplyNum = maxSupply;
        _maxMintNumPerAddress = maxMintNumPerAddress;
        _isActivityValid = false;
    }

    // bargain check, should not bargained, and can not bargain for self
    modifier canBargain(address target) {
        require(msg.sender != target, "cannot bargain for self");
        require(!isBargainedFor(target), "you have bargained");
        _;
    }

    // bargained number should reach the seted min number
    modifier bargainConditionShouldMatched() {
        require(isMyBargainConditionMatched(), "bargain condition not match");
        _;
    }

    // actitity should start and not end
    modifier activityShouldValid() {
        require(isActivityValid(), "activity is invalid");
        _;
    }

    function startActivity() public onlyOwner {
        _isActivityValid = true;
        emit ActivityStatusChange(msg.sender, bytes("start activity"));
    }

    function endActivity() public onlyOwner {
        _isActivityValid = false;
        emit ActivityStatusChange(msg.sender, bytes("end activity"));
    }

    function isActivityValid() public view returns (bool) {
        return _isActivityValid;
    }

    function getSetedMinBargainNum() public view returns (uint256) {
        return _minBargainNum;
    }

    function bargainFor(address target) public canBargain(target) activityShouldValid returns (bool) {
        bargainPool[msg.sender][target] = true;
        uint256 targetBargainNum = bargainNums[target];
        bargainNums[target] = targetBargainNum + 1;
        emit BargainForUser(msg.sender, target);
        return true;
    }

    function isBargainedFor(address target) public view returns (bool) {
        require(msg.sender != target, "cannot bargain for self");
        return bargainPool[msg.sender][target];
    }

    function isMyBargainConditionMatched() public view returns (bool) {
        return getMyBargainNum() >= _minBargainNum;
    }

    function getMyBargainNum() public view returns (uint256) {
        return bargainNums[msg.sender];
    }

    function getCurrentSuppliedNum() public view returns (uint256) {
        return _currentSuppliedNum;
    }

    function getMaxSupplyNum() public view returns (uint256) {
        return _maxSupplyNum;
    }

    function mint() public activityShouldValid bargainConditionShouldMatched {
        require(_maxSupplyNum > _currentSuppliedNum, 'reached max supply limit');
        require(balanceOf(msg.sender) < _maxMintNumPerAddress, 'reached max mint limit');
        bargainNums[msg.sender] = 0;
        _currentSuppliedNum += 1;
        _safeMint(msg.sender, tokenId.current());
        tokenId.increment();
    }
}