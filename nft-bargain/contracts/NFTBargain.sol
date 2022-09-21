// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Activity.sol";

contract NFTBargain is ERC721, Ownable {
    // 已部署的 Activity 合约地址
    address constant ACTIVITY_ADDRESS = 0xd9145CCE52D386f254917e481eB44e9943F39138;

    // nft 最大供应数量
    uint256 public constant MAX_SUPPLY_NUM = 1000;

    // 当前已 mint 出的数量
    uint256 private _currentMintedNum;

    // 每个用户最大 mint 数量
    uint256 public constant MAX_MINT_NUM_PER_ADDRESS = 5;

    uint256 public constant TOKEN_PRICE = 0.01 ether;

    string private _baseTokenURI;

    bool _isMintFinish;

    using Counters for Counters.Counter;
    Counters.Counter private tokenId;

    using Strings for uint256;

    constructor(string memory baseTokenURI)
        payable
        ERC721("NFTBargain", "NBAG")
    {
        _baseTokenURI = baseTokenURI;
        _isMintFinish = false;
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

    function getMintedNumer() public view returns (uint256) {
        return _currentMintedNum;
    }

    function isMintFinished() public view returns (bool) {
        return _isMintFinish;
    }

    function _canMint(address owner) internal view returns (bool) {
        return Activity(ACTIVITY_ADDRESS).canMintNFT(owner);
    }

    function _getBargainCountOf(address owner) internal view returns (uint256) {
        return Activity(ACTIVITY_ADDRESS).bargainCountOf(owner);
    }

    function finishMint() public onlyOwner {
        _isMintFinish = true;
    }

    // return the minted tokenId, latest bargained number which can be added to token metadata
    function mint()
        public
        payable
        returns (uint256, uint256)
    {
        require(!_isMintFinish, "mint should active");
        require(_canMint(msg.sender), "no permission to mint");
        require(msg.value >= TOKEN_PRICE, "pay fee is less than token price");
        require(MAX_SUPPLY_NUM > _currentMintedNum, "reached max supply limit");
        require(
            balanceOf(msg.sender) < MAX_MINT_NUM_PER_ADDRESS,
            "reached max mint limit"
        );

        uint256 latestBargainedNum = _getBargainCountOf(msg.sender);
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
}