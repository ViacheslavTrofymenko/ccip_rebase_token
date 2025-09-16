//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";
/**
 * @title RebaseToken
 * @author VT
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have thir own interest rate is the global interest rate in the time of depositing.
 * @dev This contract is an ERC20 token that is used to represent the Rebase Token.
 **/
contract RebaseToken is IRebaseToken, ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 oldInterestRate,
        uint256 newInterestRate
    );

    uint256 private constant PRECISION_FACTOR = 1e18;
	bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address user => uint256) private s_userInterestRate;
    mapping(address user => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

	function grantMintAndBurnRole(address _account) external onlyOwner {
		_grantRole(MINT_AND_BURN_ROLE, _account);
	}

    /**
     * @inheritdoc IRebaseToken
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

	 /**
     * @inheritdoc IRebaseToken
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @inheritdoc IRebaseToken
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @inheritdoc IRebaseToken
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @inheritdoc IRebaseToken
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @inheritdoc IRebaseToken
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @inheritdoc IRebaseToken
     */
    function balanceOf(address _user) public view override(ERC20, IRebaseToken) returns (uint256) {
        // get the current principle balance of the user
        // multiply the principle balance by interest rate of the user
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdate(_user)) /
            PRECISION_FACTOR;
    }

    /**
     * @inheritdoc IRebaseToken
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override(ERC20, IRebaseToken) returns (bool) {
        _mintAccuredInterest(msg.sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_recipient);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer tokens from sender to recipient
     * @param _sender The user to transfer the tokens from.
     * @param _recipient The user to transfer the tokens to.
     * @param _amount The amount of tokens to transfer
     * @return True if transferFrom was successful
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override(ERC20, IRebaseToken) returns (bool) {
        _mintAccuredInterest(_sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update
     * @param _user  The user to calculate the interest accumulated for
     * @return linearInterest The interest that has accumulated since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp -
            s_userLastUpdatedTimestamp[_user];
        linearInterest =
            PRECISION_FACTOR +
            (s_userInterestRate[_user] * timeElapsed);
    }

    function _mintAccuredInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }
}
