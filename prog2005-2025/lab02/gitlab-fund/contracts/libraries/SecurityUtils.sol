// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library SecurityUtils {
    // Custom error for reentrancy
    error ReentrancyGuardReentrantCall();
    
    // Reentrancy guard state
    bytes32 private constant REENTRANCY_GUARD_FREE = bytes32(0);
    bytes32 private constant REENTRANCY_GUARD_LOCKED = bytes32(uint256(1));

    /**
     * @dev Contract that enables reentrancy guard
     */
    struct NonReentrantContext {
        bytes32 _reentrancyGuardStatus;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant(NonReentrantContext storage context) {
        require(context._reentrancyGuardStatus != REENTRANCY_GUARD_LOCKED, "ReentrancyGuard: reentrant call");
        context._reentrancyGuardStatus = REENTRANCY_GUARD_LOCKED;
        _;
        context._reentrancyGuardStatus = REENTRANCY_GUARD_FREE;
    }

    /**
     * @dev Validates an array of addresses for duplicates and zero address
     */
    function validateAddresses(address[] memory addresses) internal pure returns (bool) {
        for (uint i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(0)) return false;
            for (uint j = i + 1; j < addresses.length; j++) {
                if (addresses[i] == addresses[j]) return false;
            }
        }
        return true;
    }

    /**
     * @dev Validates if an amount is non-zero and doesn't exceed a maximum
     */
    function validateAmount(uint256 amount, uint256 maxAmount) internal pure returns (bool) {
        return amount > 0 && amount <= maxAmount;
    }
}