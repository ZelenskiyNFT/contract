// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ERC721X.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ZelenskyNFT is ERC721X, Ownable {

    enum RevealStatus{
        MINT,
        REVEAL,
        REVEALED
    }

    struct PayableAddress {
        address payable addr;
        uint256 share;
    }

    event Paid(address indexed _from, uint256 _value, uint8 _whitelist);
    event Charity(address indexed _to, uint256 _value, bytes data);
    event Withdrawal(address indexed _to, uint256 _value, bytes data);

    constructor() ERC721X("ZelenskyNFT", "ZFT") {}

    uint256 public immutable priceDefault = 0.2 ether;
    uint256 public immutable priceWhitelist = 0.15 ether;

    uint256 public immutable amountWhitelist = 100;
    uint256 public immutable amountDefault = 200;

    bool private whitelistActive = false;
    bool private mintStarted = false;

    uint256 public immutable maxTotalSupply = 10000;

    string private theBaseURI;

    uint256 private charitySum = 0;
    uint256 private teamSum = 0;
    uint256 private saleSumm = 0;

    mapping(address => uint256) private mints;
    mapping(address => bool) private whitelistClaimed;

    bytes32 private root;

    RevealStatus revealStatus = RevealStatus.MINT;

    //, uint256 _startTime, bytes32[] memory _proof

    function buy(uint256 amount, bytes32[] calldata _proof) public payable {
        require(whitelistActive, "Whitelist not active");
        require(mintStarted, "Mint not started yet");

        require(msg.sender == tx.origin, "payment not allowed from contract");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_proof, root, leaf), "Address not in whitelist");
        require(whitelistClaimed[msg.sender] == false, "Whitelist already claimed");
        
        require(amount <= amountWhitelist, "too much for whitelist");
        require(mints[msg.sender] + amount <= amountWhitelist, "too much for whitelist");
        
        require(nextId + amount <= maxTotalSupply, "Maximum supply reached");
        uint256 price;
        price = priceWhitelist;

        require(msg.value >= price * amount, "Not enough eth");
        
        mints[msg.sender] += amount;

        saleSumm += msg.value;

        whitelistClaimed[msg.sender] = true;

        _mint(msg.sender, amount);
    }

    function buyDefault(uint256 amount) public payable {
        require(mintStarted, "Mint not started yet");
        require(whitelistActive == false, "Regular mint not started yet");
        require(msg.sender == tx.origin, "payment not allowed from this contract");
        require(mints[msg.sender] + amount <= amountDefault, "too much mints");

        require(nextId + amount <= maxTotalSupply, "Maximum supply reached");
        uint256 price;
        price = priceDefault;

        require(msg.value >= price * amount, "Not enough eth");

        mints[msg.sender] += amount;

        saleSumm += msg.value;

        _mint(msg.sender, amount);
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        require(revealStatus != RevealStatus.REVEALED, "URI modifications after reveal are prohibited");
        theBaseURI = newBaseURI;
        if(revealStatus == RevealStatus.MINT){
            revealStatus = RevealStatus.REVEAL;
        }else{
            revealStatus = RevealStatus.REVEALED;
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return theBaseURI;
    }

    function sendEther(address payable addr, uint256 amount, bool isCharity) private {
        (bool sent, bytes memory data) = addr.call{value: amount}("");
        require(sent, "Failed to send ether");
        if(isCharity){
            emit Charity(addr, amount, data);
            charitySum += amount;
        }else{
            emit Withdrawal(addr, amount, data);
            teamSum += amount;
        }
    }

    // Call 1 time after mint is stopped
    function pay() public onlyOwner {
        uint256 balance = address(this).balance;
        address payable charityUA = payable(0x3A0106911013eca7A0675d8F1ba7F404eD973cAb);
        address payable charityEU = payable(0x78042877DF422a9769E0fE1748FEf35d4A4718a0);
        address payable liquidity = payable(0x7A6B855D613C136098de4FEd8725DF7A7c2f7F5c);
        address payable marketing = payable(0x777C680b055cF6E97506B42DDeF4063061d7a5b4);
        address payable development = payable(0xaE987CfFaf8149EFff92546ca399D41b4Da6c57B);
        address payable team = payable(0xBedc8cDC12047465690cbc358C69b2ea671217ac);

        sendEther(charityUA, balance/2, true);
        sendEther(charityEU, balance/10, true);
        sendEther(liquidity, balance*5/100, false);
        sendEther(marketing, balance/5, false);
        sendEther(development, balance/10, false);
        sendEther(team, balance*5/100, false);
    }

    function getEthOnContract() public view returns (uint256) {
        return address(this).balance;
    }

    function checkAddressInWhiteList(bytes32[] calldata _proof) view public returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return MerkleProof.verify(_proof, root, leaf);
    }

    function setWhitelistStatus(bool status) public onlyOwner {
        whitelistActive = status;
    }

    function getWhitelistStatus() view public returns (bool) {
        return whitelistActive;
    }

    function getCharitySum() view public returns (uint256) {
        return charitySum;
    }

    function getTeamSum() view public returns (uint256) {
        return teamSum;
    }

    function setRoot(bytes32 _newRoot) public onlyOwner {
        root = _newRoot;
    }

    function startMint() public onlyOwner {
        mintStarted = true;
    }

    function stopMint() public onlyOwner {
        mintStarted = false;
    }

    function getPublicMintPrice() public pure returns (uint256) {
        return priceDefault;
    }

    function getPrivateMintPrice() public pure returns (uint256) {
        return priceWhitelist;
    }
}