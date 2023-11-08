// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {BondingCurveToken} from "../src/BondingCurveToken.sol";
import {DeployBondingCurveToken} from "../script/DeployBondingCurveToken.s.sol";

contract BondingCurveTokenTest is StdCheats, Test {
    BondingCurveToken public bondingCurveToken;
    DeployBondingCurveToken public deployer;

    uint256 public BASE_PRICE;
    uint256 public PRICE_FACTOR;

    string constant NAME = "BondingCurveToken";

    address public deployerAddress;
    address public alice;
    address public bob;

    function setUp() public {
        deployer = new DeployBondingCurveToken();
        bondingCurveToken = deployer.run();
        
        BASE_PRICE = bondingCurveToken.BASE_PRICE();
        PRICE_FACTOR = bondingCurveToken.PRICE_FACTOR();

        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    // test token name
    function test_TokenName() public {
        assertEq(bondingCurveToken.name(), NAME);
    }

    // test base price
    function test_BasePrice() public {
        assertEq(bondingCurveToken.getCurrentPrice(), 0);
    }

    // test purchase with bonding curve
    // Price formula: 
    // uint256 finalPrice = _BASE_PRICE + _PRICE_FACTOR * (totalSupply() + tokenAmount);
    // uint256 cost = ((initialPrice + finalPrice) * tokenAmount) / 2;
    function test_BuyTokens() public {
        uint256 BOB_PURCHASE_AMOUNT = 2;
        // Bob purchases tokens 0=>2
        // Purchase cost = ((0 + 2) * 2) / 2 = 2
        uint256 BOB_PURCHASE_COST = bondingCurveToken.getCostForTokens(BOB_PURCHASE_AMOUNT);
        assertEq(BOB_PURCHASE_COST, 2);

        hoax(bob, 10 ether);
        bondingCurveToken.buyTokens{value: BOB_PURCHASE_COST}(BOB_PURCHASE_AMOUNT);
        assertEq(bondingCurveToken.balanceOf(bob), BOB_PURCHASE_AMOUNT);
        assertEq(bondingCurveToken.getReserve(), BOB_PURCHASE_COST);

        uint256 ALICE_PURCHASE_AMOUNT = 2;
        // Alice purchases tokens 2=>4
        // Purchase cost = ((2 + 4) * 2) / 2 = 6
        uint256 ALICE_PURCHASE_COST = bondingCurveToken.getCostForTokens(ALICE_PURCHASE_AMOUNT);
        assertEq(ALICE_PURCHASE_COST, 6);

        hoax(alice, 10 ether);
        bondingCurveToken.buyTokens{value: ALICE_PURCHASE_COST}(ALICE_PURCHASE_AMOUNT);
        assertEq(bondingCurveToken.balanceOf(alice), ALICE_PURCHASE_AMOUNT);
        assertEq(bondingCurveToken.getReserve(), BOB_PURCHASE_COST + ALICE_PURCHASE_COST);
    }

    function test_SellTokens() public {
        uint256 BOB_PURCHASE_AMOUNT = 2;
        uint256 BOB_PURCHASE_COST = bondingCurveToken.getCostForTokens(BOB_PURCHASE_AMOUNT);
        // assertEq(BOB_PURCHASE_COST, 2);

        hoax(bob, 10 ether);
        bondingCurveToken.buyTokens{value: BOB_PURCHASE_COST}(BOB_PURCHASE_AMOUNT);
        // assertEq(bondingCurveToken.balanceOf(bob), BOB_PURCHASE_AMOUNT);
        // assertEq(bondingCurveToken.getReserve(), BOB_PURCHASE_COST);

        uint256 ALICE_PURCHASE_AMOUNT = 2;
        uint256 ALICE_PURCHASE_COST = bondingCurveToken.getCostForTokens(ALICE_PURCHASE_AMOUNT);
        // assertEq(ALICE_PURCHASE_COST, 6);

        hoax(alice, 10 ether);
        bondingCurveToken.buyTokens{value: ALICE_PURCHASE_COST}(ALICE_PURCHASE_AMOUNT);
        // assertEq(bondingCurveToken.balanceOf(alice), ALICE_PURCHASE_AMOUNT);
        // assertEq(bondingCurveToken.getReserve(), BOB_PURCHASE_COST + ALICE_PURCHASE_COST);

        // Move past lockup time
        skip(3600); // 1 hour

        // Bob sells tokens 4=>2
        vm.startPrank(bob);
        uint256 bobRevenue = bondingCurveToken.getRevenueForTokens(BOB_PURCHASE_AMOUNT);
        bondingCurveToken.sellTokens(BOB_PURCHASE_AMOUNT);
        vm.stopPrank();
        assertEq(bondingCurveToken.balanceOf(bob), 0);
        assertEq(bondingCurveToken.getReserve(), BOB_PURCHASE_COST + ALICE_PURCHASE_COST - bobRevenue);

        // Alice sells tokens 2=>0
        vm.startPrank(alice);
        uint256 aliceRevenue = bondingCurveToken.getRevenueForTokens(ALICE_PURCHASE_AMOUNT);
        bondingCurveToken.sellTokens(ALICE_PURCHASE_AMOUNT);
        vm.stopPrank();
        assertEq(bondingCurveToken.balanceOf(alice), 0);
        assertEq(bondingCurveToken.getReserve(), BOB_PURCHASE_COST + ALICE_PURCHASE_COST - bobRevenue - aliceRevenue);
    }
}