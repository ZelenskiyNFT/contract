const ZelenskyNFT = artifacts.require('ZelenskyNFT');
const {MerkleTree} = require("merkletreejs");
const keccak256 = require("keccak256");
const web3 = require('web3');
const { assert } = require("chai");
const chai = require('chai');
const BN = require('bn.js');
chai.use(require('chai-bn')(BN));

contract('ZelenskyNFT', () => {
    let zelenskyNFT = null;
    let defaultPrice = null;
    let privatePrice = null;
    before(async() => {
        zelenskyNFT = await ZelenskyNFT.deployed();
        await zelenskyNFT.startMint();
    });
    it('Deployment', async() => {
        assert(zelenskyNFT.address !== '');
    });
    it('whitelistStatus test', async() => {
        await zelenskyNFT.setWhitelistStatus(true);
        const result = await zelenskyNFT.getWhitelistStatus();
        assert(result);
    });
    it('check if address in whitelist test', async() => {

        let owner = await zelenskyNFT.owner();

        const whiteList = [
            owner,
            "0x07c2736727c9BE48D64F31132C5c7472c1C96dA1",
            "0x3143005A005ada64DD965D8A5aF94fA09050Ae69",
            "0x99A24a2360E82F9626dB186c367d7dD049A2CD73",
            "0x77d63544692c76c57596b8A859559E2d1EB589A6",
            "0x9Df6c3E3a17e34208aF7c3B9c18fDe6AE4De1491",
            "0x5cEFC1caE23B3E76f36aEBEdB8aceed4fD0bE0B4",
        ];
        // console.log(await zelenskyNFT.owner());
        const leafNodes = whiteList.map(addr => keccak256(addr));
        const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
        const rootHash = merkleTree.getRoot();
        await zelenskyNFT.setRoot(rootHash);
        const claimingAddress = leafNodes[0];
        const hexProof = merkleTree.getHexProof(claimingAddress);
        assert(await zelenskyNFT.checkAddressInWhiteList(hexProof));
    })
    it('whitelist buy passing test', async() => {
        //await zelenskyNFT.setWhitelistStatus(1);
        await zelenskyNFT.startMint();

        let owner = await zelenskyNFT.owner();

        const whiteList = [
            owner,
            "0x07c2736727c9BE48D64F31132C5c7472c1C96dA1",
            "0x3143005A005ada64DD965D8A5aF94fA09050Ae69",
            "0x99A24a2360E82F9626dB186c367d7dD049A2CD73",
            "0x77d63544692c76c57596b8A859559E2d1EB589A6",
            "0x9Df6c3E3a17e34208aF7c3B9c18fDe6AE4De1491",
            "0x5cEFC1caE23B3E76f36aEBEdB8aceed4fD0bE0B4",
        ];
        // console.log(await zelenskyNFT.owner());
        const leafNodes = whiteList.map(addr => keccak256(addr));
        const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
        const rootHash = merkleTree.getRoot();
        await zelenskyNFT.setRoot(rootHash);
        const claimingAddress = leafNodes[0];
        const hexProof = merkleTree.getHexProof(claimingAddress);
        await zelenskyNFT.buy(1, hexProof, {value: web3.utils.toWei("0.2", "ether")});
    });
    it('whitelist buy not in whitelist test', async() => {
        
        const whiteList = [
            "0x3D4F9aCCcA18Ae238125C7B459C359654A251FA1",
            "0x07c2736727c9BE48D64F31132C5c7472c1C96dA1",
            "0x3143005A005ada64DD965D8A5aF94fA09050Ae69",
            "0x99A24a2360E82F9626dB186c367d7dD049A2CD73",
            "0x77d63544692c76c57596b8A859559E2d1EB589A6",
            "0x9Df6c3E3a17e34208aF7c3B9c18fDe6AE4De1491",
            "0x5cEFC1caE23B3E76f36aEBEdB8aceed4fD0bE0B4",
        ];
        // console.log(await zelenskyNFT.owner());
        const leafNodes = whiteList.map(addr => keccak256(addr));
        const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
        const rootHash = merkleTree.getRoot();
        await zelenskyNFT.setRoot(rootHash);
        const claimingAddress = keccak256("0x2915DCa0Dd13BcFf4B1fe7a03F13ADF38900E5Fe");
        const hexProof = merkleTree.getHexProof(claimingAddress);
        try{
            await zelenskyNFT.buy(1, hexProof, {value: web3.utils.toWei("0.2", "ether")});
        }catch(e){
            assert(true);
            return;
        }
        assert(false);
        
    });

    it('regular buy test', async() => {
        await zelenskyNFT.setWhitelistStatus(false);
        const result = await zelenskyNFT.getWhitelistStatus();
        assert(result == false, "whitelist not stoppend");
        await zelenskyNFT.buyDefault(1, {value: web3.utils.toWei("0.2", "ether")});
    });

    it('pay function test', async() => {
        const ethOnContract = (await zelenskyNFT.getEthOnContract());
        await zelenskyNFT.pay();
        const ret = await zelenskyNFT.getCharitySum();
        
        const team = await zelenskyNFT.getTeamSum();
        assert(ethOnContract.toString() === "400000000000000000", "ethOnContract");
        assert(ret.toString() === "240000000000000000", "ret");
        assert(team.toString() === "160000000000000000", "team");
    });

    it("contract balance after pay test", async() => {
        const ethOnContract = (await zelenskyNFT.getEthOnContract());
        assert(ethOnContract.toNumber() === 0);
    });

});