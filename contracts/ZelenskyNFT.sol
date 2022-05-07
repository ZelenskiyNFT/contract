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
    event UriChange(string newURI);
    event WhitelistStatusChange(bool status);
    event MintStopped(bool status);
    event NewRoot(bytes32 root);
    event Payout(uint256 amount);
    event Refund(address indexed _to, uint256 amount, bytes data);
    event MintTimeSet(uint _start, uint _end);

    constructor() ERC721X("ZelenskyNFT", "ZFT") {}

    uint256 public constant priceDefault = 0.2 ether;
    uint256 public constant priceWhitelist = 0.15 ether;

    uint256 public constant amountWhitelist = 1;
    uint256 public constant amountDefault = 3;

    uint256 public constant maxTotalSupply = 10000;

    string private theBaseURI;

    uint256 private charitySum = 0;
    uint256 private teamSum = 0;
    uint256 private saleSum = 0;

    mapping(address => uint256) private mints;
    mapping(address => bool) private whitelistClaimed;

    bytes32 private root;
    bool private rootIsSet = false;

    RevealStatus revealStatus = RevealStatus.MINT;

    uint private whitelistStartTime = 0;
    uint private whitelistEndTime = 0;
    uint private publicMintStartTime = 0;

    bool private mintStopped = false;

    modifier whitelistActive() {
        require(whitelistStartTime != 0 && whitelistEndTime != 0, "Mint start time is not set");
        require(block.timestamp >= whitelistStartTime && block.timestamp <= whitelistEndTime, "Mint not started yet");
        _;
    }

    modifier whitelistEnded() {
        require(whitelistStartTime != 0 && whitelistEndTime != 0, "Mint start time is not set");
        require(block.timestamp >= whitelistEndTime, "Public mint not started yet");
        _;
    }

    modifier publicMintStarted() {
        require(block.timestamp >= publicMintStartTime, "Public mint not started yet");
        _;
    }

    //, uint256 _startTime, bytes32[] memory _proof

    function buy(uint256 amount, bytes32[] calldata _proof) public payable whitelistActive {
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

        if(msg.value > price * amount){
            uint256 refundAmount = msg.value - price * amount;
            (bool sent, bytes memory data) = msg.sender.call{value: refundAmount}("refund");
            require(sent, "Refund failed");
            emit Refund(msg.sender, refundAmount, data);
        }
        
        mints[msg.sender] += amount;

        saleSum += price * amount;

        whitelistClaimed[msg.sender] = true;

        _mint(msg.sender, amount);
    }

    function buyDefault(uint256 amount) public payable whitelistEnded {
        require(mintStopped == false, "Mint is stopped");
        //require(whitelistActive == false, "Regular mint not started yet");
        require(msg.sender == tx.origin, "payment not allowed from this contract");
        require(mints[msg.sender] + amount <= amountDefault, "too much mints for this wallet");

        require(nextId + amount <= maxTotalSupply, "Maximum supply reached");
        uint256 price;
        price = priceDefault;

        require(msg.value >= price * amount, "Not enough eth");

        if(msg.value > price * amount){
            uint256 refundAmount = msg.value - price * amount;
            (bool sent, bytes memory data) = msg.sender.call{value: refundAmount}("refund");
            require(sent, "Refund failed");
            emit Refund(msg.sender, refundAmount, data);
        }

        mints[msg.sender] += amount;

        saleSum += price * amount;

        _mint(msg.sender, amount);
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        require(revealStatus != RevealStatus.REVEALED, "URI modifications after reveal are prohibited");
        theBaseURI = newBaseURI;
        emit UriChange(newBaseURI);
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
    function pay() public onlyOwner whitelistEnded {
        uint256 balance = address(this).balance;
        emit Payout(balance);
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

    function getWhitelistStatus() view public returns (bool) {
        return block.timestamp >= whitelistStartTime && block.timestamp <= whitelistEndTime;
    }

    function getCharitySum() view public returns (uint256) {
        return charitySum;
    }

    function getTeamSum() view public returns (uint256) {
        return teamSum;
    }

    function setRoot(bytes32 _newRoot) public onlyOwner {
        require(rootIsSet == false, "Root already set");
        rootIsSet = true;
        root = _newRoot;
        emit NewRoot(_newRoot);
    }

    function stopMint() public onlyOwner {
        mintStopped = true;
        emit MintStopped(true);
    }
}