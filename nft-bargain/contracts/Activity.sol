// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IActivity {
    enum ActivitySteps {
        NotStart, // 活动未开始
        Active, // 活动进行中
        Finished // 活动已结束
    }

    event ActivityStatusChange(address indexed owner, bytes message);

    function startActivity() external;
    function endActivity() external;
}

interface IBargain {
    event BargainForUser(address indexed from, address indexed to);

    // 为他人助力
    function bargainFor(address target) external returns (bool);
}

contract Activity is IActivity, IBargain, Ownable {
    // 活动名称
    string _activityName;

    // 最低助力次数，在一个周期内，必须达到这个次数，才能 mint
    uint256 public constant MIN_BARGAIN_NUM_TO_MINT = 1;

    // 每个用户最多能给几个人助力
    uint256 public constant MAX_BARGAIN_FOR_COUNT = 5;

    // 记录推广人已被助力的次数，在 mint 之后，此数字会被清零
    mapping(address => uint256) bargainNums;

    // 记录助力人的助力记录
    mapping(address => mapping(address => bool)) bargainPool;

    // 记录助力人已助力的次数
    mapping(address => uint256) bargainForCounts;

    ActivitySteps _currentActivityStep;

    constructor(string memory name) {
        _activityName = name;
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
            bargainForCounts[msg.sender] < MAX_BARGAIN_FOR_COUNT,
            "reach the max bargain count"
        );
        _;
    }

    // actitity should be Active
    modifier activityShouldValid() {
        require(_currentActivityStep == ActivitySteps.Active, "activity is invalid");
        _;
    }

    function activityName() public view returns (string memory) {
        return _activityName;
    }

    function _changeActivityStepTo(ActivitySteps step) internal onlyOwner {
        _currentActivityStep = step;
    }

    function startActivity() public onlyOwner {
        _changeActivityStepTo(ActivitySteps.Active);
        emit ActivityStatusChange(msg.sender, bytes("start activity"));
    }

    function endActivity() public onlyOwner {
        _changeActivityStepTo(ActivitySteps.Finished);
        emit ActivityStatusChange(msg.sender, bytes("end activity"));
    }

    function isBargainedFor(address target) internal view returns (bool) {
        require(msg.sender != target, "cannot bargain for self");
        return bargainPool[msg.sender][target];
    }

    function isBargainConditionMatched(address target) internal view returns (bool) {
        return bargainNums[target] >= MIN_BARGAIN_NUM_TO_MINT;
    }

    /**
     * 用户发起助力
     */
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

    function isActivityFinished() public view returns (bool) {
        return _currentActivityStep == ActivitySteps.Finished;
    }

    /**
     * 目标用户是否可以 mint NFT，供其他合约调用
     * 满足两个条件才可以 mint:
     * - 活动正在进行中
     * - 当前周期内，满足助力要求
     */
    function canMintNFT(address target) external view returns (bool) {
        require(_currentActivityStep == ActivitySteps.Active, "activity is not active");
        return isBargainConditionMatched(target);
    }

    /**
     * 获取用户当前的助力次数
     */
    function bargainCountOf(address target) external view returns (uint256) {
        return bargainNums[target];
    }
}