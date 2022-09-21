// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IActivity {
    enum ActivitySteps {
        NotStart, // 活动未开始
        Active, // 活动进行中
        ActivityFinished, // 活动已结束，等待管理员分配奖池
        AllocateRewardFinished // 奖金分配结束，用户可以提现
    }

    event ActivityStatusChange(address indexed owner, bytes message);

    function startActivity() external;
    function endActivity() external;
}

interface IReward {
    function allocateReward() external;
}

interface IActivityWithReward is IActivity, IReward {}

interface IBargain {
    event BargainForUser(address indexed from, address indexed to);

    // msg.sender start to bargin for target user
    function bargainFor(address target) external returns (bool);

    // check if msg.sender has bargined for target user or not
    function isBargainedFor(address target) external view returns (bool);

    // check if my bargain condition has been matched
    function isMyBargainConditionMatched() external view returns (bool);
}

contract NFTBargain is ERC721, Ownable, PullPayment, IActivityWithReward, IBargain {
    // 最低助力次数，在一个周期内，必须达到这个次数，才能 mint
    uint256 public constant MIN_BARGAIN_NUM_TO_MINT = 1;

    // nft 最大供应数量
    uint256 public constant MAX_SUPPLY_NUM = 1000;

    // 当前已 mint 出的数量
    uint256 private _currentMintedNum;

    // 每个用户最大 mint 数量
    uint256 public constant MAX_MINT_NUM_PER_ADDRESS = 5;

    // 每个用户最多能给几个人助力
    uint256 public constant MAX_BARGAIN_FOR_COUNT = 5;

    uint256 public constant TOKEN_PRICE = 0.01 ether;

    // 记录推广人已被助力的次数，在 mint 之后，此数字会被清零
    mapping(address => uint256) bargainNums;

    // 记录助力人的助力记录
    mapping(address => mapping(address => bool)) bargainPool;

    // 记录助力人已助力的次数
    mapping(address => uint256) bargainForCounts;

    ActivitySteps _currentActivityStep;

    string private _baseTokenURI;

    using Counters for Counters.Counter;
    Counters.Counter private tokenId;

    using Strings for uint256;
    using SafeMath for uint256;

    constructor(string memory baseTokenURI)
        payable
        ERC721("NFTBargain", "NBAG")
    {
        _baseTokenURI = baseTokenURI;
        _currentActivityStep = ActivitySteps.NotStart;
    }

    // override get base uri func
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // override tokenURI
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireMinted(_tokenId);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(baseURI, "?filename=", _tokenId.toString())
                )
                : "";
    }

    /**
     * bargain rules
     * - should not bargained for the same target user
     * - and can not bargain for self
     * - and count of bargain should less or equal than _maxBargainForCount
     */
    modifier canBargain(address target) {
        require(msg.sender != target, "cannot bargain for self");
        require(!isBargainedFor(target), "you have bargained");
        require(
            bargainForCounts[msg.sender] <= MAX_BARGAIN_FOR_COUNT,
            "reach the max bargain count"
        );
        _;
    }

    // bargained number should reach the seted min number
    modifier bargainConditionShouldMatched() {
        require(isMyBargainConditionMatched(), "bargain condition not match");
        _;
    }

    // actitity should be Active
    modifier activityShouldValid() {
        require(_currentActivityStep == ActivitySteps.Active, "activity is invalid");
        _;
    }

    modifier allocateRewardShouldStart() {
        require(_currentActivityStep == ActivitySteps.ActivityFinished, "allocate reward not start");
        _;
    }

    modifier withdrawRewardShouldStart() {
        require(_currentActivityStep == ActivitySteps.AllocateRewardFinished, "withdraw reward not start");
        _;
    }

    function _changeActivityStepTo(ActivitySteps step) internal onlyOwner {
        _currentActivityStep = step;
    }

    function startActivity() public onlyOwner {
        _changeActivityStepTo(ActivitySteps.Active);
        emit ActivityStatusChange(msg.sender, bytes("start activity"));
    }

    function endActivity() public onlyOwner {
        _changeActivityStepTo(ActivitySteps.ActivityFinished);
        emit ActivityStatusChange(msg.sender, bytes("end activity"));
    }

    function bargainFor(address target)
        public
        canBargain(target)
        activityShouldValid
        returns (bool)
    {
        // 增加砍一刀记录
        bargainPool[msg.sender][target] = true;

        // 更新砍一刀次数
        bargainForCounts[msg.sender] += 1;

        // 更新推广人助力次数
        bargainNums[target] += 1;

        emit BargainForUser(msg.sender, target);
        return true;
    }

    function isBargainedFor(address target) public view returns (bool) {
        require(msg.sender != target, "cannot bargain for self");
        return bargainPool[msg.sender][target];
    }

    function isMyBargainConditionMatched() public view returns (bool) {
        return getMyBargainNum() >= MIN_BARGAIN_NUM_TO_MINT;
    }

    function getMyBargainNum() public view returns (uint256) {
        return bargainNums[msg.sender];
    }

    function getMyBargainedForCount() public view returns (uint256) {
        return bargainForCounts[msg.sender];
    }

    function getCurrentSuppliedNum() public view returns (uint256) {
        return _currentMintedNum;
    }

    // return the minted tokenId, latest bargained number which can be added to token metadata
    function mint()
        public
        payable
        activityShouldValid
        bargainConditionShouldMatched
        returns (uint256, uint256)
    {
        require(msg.value >= TOKEN_PRICE, "pay fee is less than token price");
        require(MAX_SUPPLY_NUM > _currentMintedNum, "reached max supply limit");
        require(
            balanceOf(msg.sender) < MAX_MINT_NUM_PER_ADDRESS,
            "reached max mint limit"
        );

        uint256 latestBargainedNum = bargainNums[msg.sender];
        bargainNums[msg.sender] = 0;

        _currentMintedNum += 1;

        uint256 currentTokenId = tokenId.current();
        _safeMint(msg.sender, currentTokenId);
        tokenId.increment();

        return (currentTokenId, latestBargainedNum);
    }

    event ETHReceive(address, uint256);

    receive() external payable {
        emit ETHReceive(msg.sender, msg.value);
    }

    /**
     * 获取奖池总金额
     */
    function totalRewards() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * 获取平均金额
     * avgAmount = 奖池总金额 / NFT minted 数量
     */
    function _getAverageRewardAmount() internal view allocateRewardShouldStart returns (uint256) {
        require(_currentMintedNum > 0, "minted number should larger than 0");
        uint256 rewards = totalRewards();
        require(rewards > 0, "rewards should larger than 0");
        return rewards.div(_currentMintedNum);
    }

    // /**
    //  * 获取用户 mint 数量
    //  */
    // function _getMintedNum(address owner) internal view allocateRewardShouldStart returns (uint256) {
    //     return balanceOf(owner);
    // }

    // /**
    //  * 获取用户的奖金总额
    //  * totalAmount = 平均金额 * 用户 mint 数量
    //  */
    // function _getRewardAmountOf(address owner) internal view allocateRewardShouldStart returns (uint256) {
    //     uint256 avgAmount = _getAverageRewardAmount();
    //     uint256 myMintedNum = _getMintedNum(owner);
    //     require(myMintedNum > 0, "user should minted");
    //     return avgAmount.mul(myMintedNum);
    // }

    /**
     * 管理员调用，给用户分配奖金
     */
    function allocateReward() public onlyOwner allocateRewardShouldStart {
        uint256 rewardAmount = _getAverageRewardAmount();
        for (uint256 i = 0; i < _currentMintedNum; i++) {
            address user = ownerOf(i);
            _asyncTransfer(user, rewardAmount);
        }
        _changeActivityStepTo(ActivitySteps.AllocateRewardFinished);
    }

    /**
     * 用户调用，取现奖金
     */
    function withdrawPayments(address payable payee) public withdrawRewardShouldStart override {
        require(msg.sender == payee, "only withdraw for self");
        super.withdrawPayments(payee);
    }
}