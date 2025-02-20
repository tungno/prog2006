// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SecurityUtils
 * @notice Library providing security utilities for smart contracts
 * @dev Includes reentrancy protection, validation functions, and security checks
 */
library SecurityUtils {
    // Custom errors for better gas efficiency
    error ReentrancyGuardReentrantCall();
    error InvalidAddress();
    error InvalidAmount();
    error DuplicateAddress();
    error ValidationFailed();

    // Reentrancy guard states
    bytes32 private constant REENTRANCY_GUARD_FREE = bytes32(0);
    bytes32 private constant REENTRANCY_GUARD_LOCKED = bytes32(uint256(1));

    /**
     * @dev Struct for reentrancy guard context
     */
    struct NonReentrantContext {
        bytes32 _reentrancyGuardStatus;
    }

    /**
     * @dev Enhanced reentrancy guard modifier with custom error
     */
    modifier nonReentrant(NonReentrantContext storage context) {
        if (context._reentrancyGuardStatus == REENTRANCY_GUARD_LOCKED) 
            revert ReentrancyGuardReentrantCall();
        
        context._reentrancyGuardStatus = REENTRANCY_GUARD_LOCKED;
        _;
        context._reentrancyGuardStatus = REENTRANCY_GUARD_FREE;
    }

    /**
     * @dev Validates an array of addresses
     * @param addresses Array of addresses to validate
     * @return bool Returns true if all addresses are valid
     */
    function validateAddresses(address[] memory addresses) internal pure returns (bool) {
        if (addresses.length == 0) revert ValidationFailed();

        for (uint i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(0)) revert InvalidAddress();
            
            // Check for duplicates
            for (uint j = i + 1; j < addresses.length; j++) {
                if (addresses[i] == addresses[j]) revert DuplicateAddress();
            }
        }
        return true;
    }

    /**
     * @dev Validates if an amount is within acceptable range
     * @param amount Amount to validate
     * @param maxAmount Maximum allowed amount
     * @return bool Returns true if amount is valid
     */
    function validateAmount(uint256 amount, uint256 maxAmount) internal pure returns (bool) {
        if (amount == 0 || amount > maxAmount) revert InvalidAmount();
        return true;
    }

    /**
     * @dev Validates if a single address is valid
     * @param addr Address to validate
     * @return bool Returns true if address is valid
     */
    function validateAddress(address addr) internal pure returns (bool) {
        if (addr == address(0)) revert InvalidAddress();
        return true;
    }

    /**
     * @dev Validates a timestamp is within a valid range
     * @param timestamp Timestamp to validate
     * @param maxDuration Maximum allowed duration from now
     * @return bool Returns true if timestamp is valid
     */
    function validateTimestamp(uint256 timestamp, uint256 maxDuration) internal view returns (bool) {
        return timestamp > block.timestamp && 
               timestamp <= block.timestamp + maxDuration;
    }

    /**
     * @dev Safe math function to add two uint256 with overflow check
     */
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Safe math function to subtract two uint256 with underflow check
     */
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction underflow");
        return a - b;
    }
}