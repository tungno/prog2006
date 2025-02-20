// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IFundManager {
    // Events
    event FundsDeposited(address indexed funder, uint256 amount);
    event BountyAllocated(uint256 indexed issueId, uint256 amount);
    event FundsReallocated(uint256 indexed fromIssue, uint256 indexed toIssue, uint256 amount);
    event BountyCancelled(uint256 indexed issueId);

    // Functions
    function depositFunds() external payable;
    function allocateBounty(uint256 issueId, uint256 amount) external;
    function reallocateFunds(uint256 fromIssue, uint256 toIssue, uint256 amount) external;
    function getIssueBounty(uint256 issueId) external view returns (uint256);
    function getFunderBalance(address funder) external view returns (uint256);
    function getBountyDetails(uint256 issueId) external view returns (
        uint256 amount,
        address funder,
        uint256 createdAt,
        bool active
    );
}