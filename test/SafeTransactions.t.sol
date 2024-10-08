// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SafeTransactions} from "../src/SafeTransactions.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract TestSafeTransactions is Test {
    SafeTransactions public safeTransactions = new SafeTransactions();

    address payable jaxon = payable(address(0x10));
    address public lockett = address(0x2);
    address public dk = address(0x3);

   MockERC20 public baseToken;
   MockERC20 public baseTokeern;

    function setUp() public {
        safeTransactions = new SafeTransactions();
        baseToken = new MockERC20("Juan", "JUAN");
        baseTokeern = new MockERC20("Carlos", "CARLOS");

        // //delete next four lines
        // vm.deal(jaxon, 1 ether);
        // vm.deal(lockett, 1 ether);

        // baseToken.mint(jaxon, 1000);
        // baseToken.mint(lockett, 1000);
    }

    function testViewTokenTransaction(uint256 amount, string calldata secret) public {
        vm.assume(amount < type(uint128).max);

        baseToken.mint(jaxon, amount);

        vm.startPrank(jaxon);

        baseToken.approve(address(safeTransactions), amount);
        safeTransactions.sendToken(lockett, amount, secret, address(baseToken));
        assertEq(safeTransactions.viewTokenTransaction(jaxon, lockett, secret, address(baseToken)), amount);

        vm.stopPrank();
    }

    function testViewEthTransaction(uint256 amount, string calldata secret) public {
        vm.deal(jaxon, amount);

        vm.startPrank(jaxon);

        safeTransactions.sendEth{value: amount}(lockett, secret);
        assertEq(safeTransactions.viewEthTransaction(jaxon, lockett, secret), amount);

        vm.stopPrank();
    }

    function testSendEth(uint256 amount, string calldata secret) public {
        vm.deal(jaxon, amount);

        vm.startPrank(jaxon);

        safeTransactions.sendEth{value: amount}(lockett, secret);
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret))), amount);

        vm.stopPrank();
    }

    function testCancelSendEth(uint256 amount, string calldata secret) public {
        vm.assume(amount < type(uint64).max);

        vm.deal(jaxon, amount);

        vm.prank(jaxon);
        safeTransactions.sendEth{value: amount}(lockett, secret);

        //non tx creator can't cancel someone else's tx
        vm.startPrank(lockett);
        safeTransactions.cancelSendEth(lockett, secret);
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret))), amount);
        vm.stopPrank();

        vm.startPrank(jaxon);

        //cancel tx with different secret shouldn't affect original tx
        safeTransactions.cancelSendEth(lockett, "secret1");
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret))), amount);

        //correct cancel tx should work
        // Check that transaction mapping stores 0 noe and check that sender is refunded
        safeTransactions.cancelSendEth(lockett, secret);
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret))), 0);
        assertEq(address(jaxon).balance, amount);

        //cancel tx twice shouldn't do anything
        safeTransactions.cancelSendEth(lockett, secret);
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret))), 0);
        assertEq(address(jaxon).balance, amount);

        vm.stopPrank();

        vm.startPrank(lockett);

        //claiming tx after cancel should not work
        uint256 balance = address(jaxon).balance;
        safeTransactions.claimEth(jaxon, secret);
        uint256 balance2 = address(jaxon).balance;
        assertEq(balance, balance2);

        vm.stopPrank();
    }

    function testClaimEth(uint256 amount, string calldata secret) public {
        vm.assume(amount < type(uint128).max);

        vm.deal(jaxon, amount);

        vm.prank(jaxon);

        // payable(address(0x0)).transfer(1 ether);
        safeTransactions.sendEth{value: amount}(lockett, secret);

        vm.startPrank(dk);

        //wrong receiver shohuld not be able to claim tx
        uint256 balance = address(dk).balance;
        safeTransactions.claimEth(jaxon, secret);
        uint256 balance2 = address(dk).balance;
        assertEq(balance, balance2);

        vm.stopPrank();

        vm.startPrank(lockett);

        //wrong secret should not be able to claim tx
        balance = address(lockett).balance;
        safeTransactions.claimEth(jaxon, "tokern");
        balance2 = address(lockett).balance;
        assertEq(balance, balance2);

        //correct claim should work
        balance = address(lockett).balance;
        safeTransactions.claimEth(jaxon, secret);
        balance2 = address(lockett).balance;
        assertEq(balance, balance2 - amount);

        vm.stopPrank();
    }

    function testSendToken(uint256 amount, string calldata secret) public {
        vm.assume(amount < type(uint128).max);

        baseToken.mint(jaxon, 2*amount);

        vm.startPrank(jaxon);

        baseToken.approve(address(safeTransactions), 2*amount);
        safeTransactions.sendToken(lockett, amount, secret, address(baseToken));
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret, address(baseToken)))), amount);

        safeTransactions.sendToken(lockett, amount, secret, address(baseToken));
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret, address(baseToken)))), 2*amount);

        vm.stopPrank();
    }

    function testCancelSendToken(uint256 amount, string calldata secret) public {
        vm.assume(amount < type(uint128).max);
        baseToken.mint(jaxon, amount);

        vm.startPrank(jaxon);
        baseToken.approve(address(safeTransactions), amount);
        safeTransactions.sendToken(lockett, amount, secret, address(baseToken));
        vm.stopPrank();

        //non tx creator can't cancel someone else's tx
        vm.prank(lockett);
        safeTransactions.cancelSendToken(lockett, secret, address(baseToken));
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret, address(baseToken)))), amount);

        vm.startPrank(jaxon);

        //cancel tx with wrong tokena address shouldn't affect original tx
        safeTransactions.cancelSendToken(lockett, secret, address(baseTokeern));
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret, address(baseToken)))), amount);

        //cancel tx with different secret shouldn't affect original tx
        safeTransactions.cancelSendToken(lockett, "secret1", address(baseToken));
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret, address(baseToken)))), amount);

        //correct cancel tx should work
        assert(baseToken.balanceOf(jaxon) == 0);
        safeTransactions.cancelSendToken(lockett, secret, address(baseToken));
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret, address(baseToken)))), 0);
        assertEq(baseToken.balanceOf(jaxon), amount);

        //cancel tx twice shouldn't do anything
        safeTransactions.cancelSendToken(lockett, secret, address(baseToken));
        assertEq(safeTransactions.transactions(keccak256(abi.encodePacked(jaxon, lockett, secret, address(baseToken)))), 0);

        vm.stopPrank();

        vm.startPrank(lockett);

        //claiming tx after cancel should not work
        uint256 balance = baseToken.balanceOf(jaxon);
        safeTransactions.claimToken(jaxon, secret, address(baseToken));
        uint256 balance2 = baseToken.balanceOf(jaxon);
        assertEq(balance, balance2);

        vm.stopPrank();
    }

    function testClaimToken(uint256 amount, string calldata secret) public {
        vm.assume(amount < type(uint128).max);
        baseToken.mint(jaxon, amount);

        vm.startPrank(jaxon);
        baseToken.approve(address(safeTransactions), amount);
        safeTransactions.sendToken(lockett, amount, secret, address(baseToken));
        vm.stopPrank();

        vm.startPrank(dk);

        //wrong receiver shohuld not be able to claim tx
        uint256 balance = baseToken.balanceOf(dk);
        safeTransactions.claimToken(jaxon, secret, address(baseToken));
        uint256 balance2 = baseToken.balanceOf(dk);
        assertEq(balance, balance2);
        vm.stopPrank();

        vm.startPrank(lockett);

        //wrong secret should not be able to claim tx
        balance = baseToken.balanceOf(lockett);
        safeTransactions.claimToken(jaxon, "tokern", address(baseToken));
        balance2 = baseToken.balanceOf(lockett);
        assertEq(balance, balance2);

        //wrong token address should not be able to claim tx
        balance = baseToken.balanceOf(lockett);
        safeTransactions.claimToken(jaxon, secret, address(baseTokeern));
        balance2 = baseToken.balanceOf(lockett);
        assertEq(balance, balance2);

        //correct claim should work
        balance = baseToken.balanceOf(lockett);
        safeTransactions.claimToken(jaxon, secret, address(baseToken));
        balance2 = baseToken.balanceOf(lockett);
        assertEq(balance + amount, balance2);

        vm.stopPrank();
    }
}
