// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { ResearchPaperNFT } from "./ResearchPaperNFT.sol";

contract DRPV {
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;
    LicensingModule public immutable LICENSING_MODULE;
    PILicenseTemplate public immutable PIL_TEMPLATE;
    ResearchPaperNFT public immutable ResearchPaper_NFT;
    address payable owner;
    uint public publishFee;
    uint public licenseFeePercent;

    struct Paper {
        string authorName;
        address authorAddress;
        string title;
        string ipfsHash;
        uint256 price;
    }

    Paper[] public papers;
    mapping(address => Paper) public paperDetails;
    mapping(address => address[]) public licensesPurchasedByUser;
    
    event PaperPublished(address paperId, string author, string title, uint256 price);
    event LicensePurchased(address paperId, address buyer);

    constructor(address ipAssetRegistry, address licensingModule, address pilTemplate) {
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = LicensingModule(licensingModule);
        PIL_TEMPLATE = PILicenseTemplate(pilTemplate);
        ResearchPaper_NFT = new ResearchPaperNFT("Research Paper NFT", "RPNFT");
        owner = payable(msg.sender);
        publishFee = 0.001 ether; 
        licenseFeePercent = 1; 
    }

    function publishPaper(
        string calldata _authorName,
        string calldata _title,
        string calldata _ipfsHash,
        uint256 _price
    ) public payable {
        require(msg.value == publishFee, "Incorrect value sent for publishing fee");
        require(_price > 0, "Price must be greater than zero");
        require(bytes(_authorName).length > 0, "Author name cannot be empty");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");

        uint tokenId = ResearchPaper_NFT.mintNFT(msg.sender, _ipfsHash);
        address ipId = IP_ASSET_REGISTRY.register(block.chainid, address(ResearchPaper_NFT), tokenId);
        attachLicenseTerms(ipId);

        papers.push(Paper({
            authorName: _authorName,
            authorAddress: msg.sender,
            title: _title,
            ipfsHash: _ipfsHash,
            price: _price
        }));

        paperDetails[ipId] = Paper({
            authorName: _authorName,
            authorAddress: msg.sender,
            title: _title,
            ipfsHash: _ipfsHash,
            price: _price
        });

        owner.transfer(msg.value); // Transfer fee to owner
        emit PaperPublished(ipId, _authorName, _title, _price);
    }

    function attachLicenseTerms(address ipId) internal {
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), 2);
    }

    function mintLicenseToken(address ipId) internal returns (uint256 startLicenseTokenId) {
        startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: 2,
            amount: paperDetails[ipId].price,
            receiver: msg.sender,
            royaltyContext: ""
        });
    }

    function purchaseLicense(address _paperId) public payable returns (uint licenseId) {
        require(_paperId != address(0), "Paper does not exist");

        Paper storage paper = paperDetails[_paperId];
        require(paper.authorAddress != address(0), "Invalid paperId");
        require(msg.value == paper.price, "Incorrect value sent for license fee");
        
        uint licenseFee = (paper.price * licenseFeePercent) / 100;

        licenseId = mintLicenseToken(_paperId);
        licensesPurchasedByUser[msg.sender].push(_paperId);

        payable(paper.authorAddress).transfer(paper.price - licenseFee); // Transfer price to paper author
        owner.transfer(licenseFee); // Transfer license fee to owner
        emit LicensePurchased(_paperId, msg.sender);
    }

    function getPaper(address _paperId) public view returns (address, string memory, string memory, uint256) {
        Paper memory paper = paperDetails[_paperId];
        return (paper.authorAddress, paper.title, paper.ipfsHash, paper.price);
    }

    function getAllPapers() public view returns (Paper[] memory) {
        return papers;
    }

    function getAllPapersByUser(address _user) public view returns (Paper[] memory purchases) {
        address[] storage licenses = licensesPurchasedByUser[_user];
        purchases = new Paper[](licenses.length);
        for (uint i = 0; i < licenses.length; i++) {
            purchases[i] = paperDetails[licenses[i]];
        }
    }
}
