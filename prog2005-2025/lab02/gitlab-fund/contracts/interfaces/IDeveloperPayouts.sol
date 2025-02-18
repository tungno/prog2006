// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDeveloperPayouts {
    // Events
    event BountyClaimed(uint256 indexed issueId, address indexed developer);
    event PayoutProcessed(uint256 indexed issueId, address indexed developer, uint256 amount);
    event ClaimCancelled(uint256 indexed issueId, address indexed developer);

    // Functions
    function claimBounty(uint256 issueId) external;
    function processPayout(uint256 issueId) external;
    function cancelClaim(uint256 issueId) external;
    function getClaimStatus(uint256 issueId) external view returns (bool claimed, address developer, uint256 amount);
}