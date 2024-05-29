// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";

import { DRPV } from "../src/DRPV.sol";
import { ResearchPaperNFT } from "../src/ResearchPaperNFT.sol";

contract DRPVTest is Test {
    DRPV internal drpv;
    ResearchPaperNFT internal nft;
    IPAssetRegistry internal registry;
    LicensingModule internal licensingModule;
    PILicenseTemplate internal pilTemplate;

    address public user1;
    address public user2;

    function setUp() public {
        user1 = address(0x123);
        user2 = address(0x456);

        nft = new ResearchPaperNFT("Research Paper NFT", "RPNFT");
        registry = new IPAssetRegistry();
        licensingModule = new LicensingModule();
        pilTemplate = new PILicenseTemplate();

        drpv = new DRPV(address(registry), address(licensingModule), address(pilTemplate));
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testPublishPaper() public {
        vm.startPrank(user1);
        uint publishFee = drpv.publishFee();
        uint paperPrice = 1 ether;
        drpv.publishPaper{value: publishFee}("Author1", "Title1", "ipfsHash1", paperPrice);

        (address authorAddress, string memory title, string memory ipfsHash, uint256 price) = drpv.getPaper(0);
        assertEq(authorAddress, user1);
        assertEq(title, "Title1");
        assertEq(ipfsHash, "ipfsHash1");
        assertEq(price, paperPrice);
        vm.stopPrank();
    }

    function testPurchaseLicense() public {
        vm.startPrank(user1);
        uint publishFee = drpv.publishFee();
        uint paperPrice = 1 ether;
        drpv.publishPaper{value: publishFee}("Author1", "Title1", "ipfsHash1", paperPrice);
        vm.stopPrank();

        vm.startPrank(user2);
        drpv.purchaseLicense{value: paperPrice}(0);
        Paper[] memory purchasedPapers = drpv.getAllPapersByUser(user2);
        assertEq(purchasedPapers.length, 1);
        assertEq(purchasedPapers[0].title, "Title1");
        vm.stopPrank();
    }

    function testPublishFee() public {
        uint expectedFee = 0.001 ether;
        assertEq(drpv.publishFee(), expectedFee);
    }

    function testLicenseFeePercent() public {
        uint expectedPercent = 1;
        assertEq(drpv.licenseFeePercent(), expectedPercent);
    }

    function testOwnerReceivesFees() public {
        vm.startPrank(user1);
        uint publishFee = drpv.publishFee();
        uint paperPrice = 1 ether;

        uint initialOwnerBalance = address(drpv.owner()).balance;
        drpv.publishPaper{value: publishFee}("Author1", "Title1", "ipfsHash1", paperPrice);
        uint postPublishOwnerBalance = address(drpv.owner()).balance;
        assertEq(postPublishOwnerBalance, initialOwnerBalance + publishFee);
        vm.stopPrank();

        vm.startPrank(user2);
        drpv.purchaseLicense{value: paperPrice}(0);
        uint postLicenseOwnerBalance = address(drpv.owner()).balance;
        uint licenseFee = (paperPrice * drpv.licenseFeePercent()) / 100;
        assertEq(postLicenseOwnerBalance, postPublishOwnerBalance + licenseFee);
        vm.stopPrank();
    }
}


