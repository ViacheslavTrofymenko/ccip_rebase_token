// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IRebaseToken, RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {

	error Is_Not_Success();

	RebaseToken private rebaseToken;
	Vault private vault;

	address public owner = makeAddr("owner");
	address public user = makeAddr("user");

	function setUp() public {
		vm.startPrank(owner);
		rebaseToken = new RebaseToken();
		vault = new Vault(IRebaseToken(address(rebaseToken)));
		rebaseToken.grantMintAndBurnRole(address(vault));
		vm.deal(owner, 1e18);
		(bool success, )= payable(address(vault)).call{value: 1e18}("");
		if (!success) {
			revert Is_Not_Success();
		}
		vm.stopPrank();
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
		assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
		vm.stopPrank();
	}
}
