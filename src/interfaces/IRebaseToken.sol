// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRebaseToken {
	function grantMintAndBurnRole(address _account) external;

	/**
     * @notice Set interest rate in the contract
     * @param _newInterestRate The new interest rate to set
     * @dev The interest rate can only decrease
     */
	function setInterestRate(uint256 _newInterestRate) external;

	/**
     * @notice Get interest rate for the contract
     * @return The interest rate for the contract
     */
    function getInterestRate() external view returns (uint256);

	/**
     * @notice Get the interest rate for the user
     * @param _user The user to get the interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256);

	/**
     * @notice GEt the principle balance of a user. This is the number of tokens that have currently been minted to the user.
     * @notice Not including any interest that has accrued since the last time the user interacted with the protocol.
     * @param _user The user to get the principle balance for
     * @return The principle balance of the user
     */
    function principleBalanceOf(address _user) external view returns (uint256);

	/**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the tokens to
     * @param _amount The amount of tokens to mint
     * @param _interestRate The interest rate
     */
    function mint(address _to, uint256 _amount, uint256 _interestRate) external;

	/**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn the tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external;

	/**
     * @notice Calculate the balance for the user including the interest that has accumulated since last update
     * @param _user The user to calculate balance for
     * @return The balance of the user
     */
    function balanceOf(address _user) external view returns (uint256);

	/**
     * @notice Transfer tokens from one user to another
     * @param _recipient The user to transfer the tokens to.
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) external returns (bool);

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
    ) external returns (bool);
}
