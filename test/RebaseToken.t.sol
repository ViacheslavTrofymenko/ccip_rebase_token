// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRebaseToken, RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    error Is_Not_Success();

    RebaseToken private rebaseToken;
    Vault private vault;

    uint256 public constant INTEREST_RATE = 4e10;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.deal(owner, 1e18);
        (bool success, ) = payable(address(vault)).call{value: 1e18}("");
        if (!success) {
            revert Is_Not_Success();
        }
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success, ) = payable(address(vault)).call{value: rewardAmount}(
            ""
        );
        if (!success) revert Is_Not_Success();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startbalance", startBalance);
        assertEq(startBalance, amount);
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);
        assertApproxEqAbs(
            endBalance - middleBalance,
            middleBalance - startBalance,
            1
        );
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(user.balance, amount);

        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(
        uint256 depositAmount,
        uint256 time
    ) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);

        vm.prank(user);
        vault.redeem(type(uint256).max);
        uint256 ethBalance = user.balance;

        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(INTEREST_RATE);

        vm.prank(user);
        bool success = rebaseToken.transfer(user2, amountToSend);
        if (!success) revert Is_Not_Success();
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        // check the user interest rate has been inherited (5e10 not 4e10)
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testInterestRateCanOnlyDecresed(uint256 newInterestRate) public {
        uint256 currentInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(
            newInterestRate,
            currentInterestRate + 1,
            type(uint96).max
        );
        vm.prank(owner);
		 vm.expectRevert(
				abi.encodeWithSelector(
				RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector,
				currentInterestRate,
				newInterestRate
			)
		);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn() public {
        uint256 amount = 1e15;
        uint256 _interestRate = rebaseToken.getInterestRate();
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.mint(user, amount, _interestRate);

        vm.prank(user);
        vm.expectRevert();
        rebaseToken.burn(user, amount);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testRevertRedeem() public {
        uint256 amount = 5e15;
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        vm.prank(user);
        vm.expectRevert();
        vault.redeem(amount + 1);
    }
}
