// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IFundManager.sol";
import "./libraries/SecurityUtils.sol";

contract FundManager is IFundManager {
    using SecurityUtils for SecurityUtils.NonReentrantContext;

    SecurityUtils.NonReentrantContext private _reentrancyContext;

    // Mapping of funder address to their total funds
    mapping(address => uint256) public funderBalances;
    
    // Mapping of issue ID to bounty amount
    mapping(uint256 => uint256) public issueBounties;
    
    // Total funds in the contract
    uint256 public totalFunds;

    // Minimum deposit amount
    uint256 public constant MIN_DEPOSIT = 0.01 ether;

    modifier onlyFunder(uint256 issueId) {
        require(funderBalances[msg.sender] >= issueBounties[issueId], "Not enough funds");
        _;
    }

    receive() external payable {
        depositFunds();
    }

    function depositFunds() public payable override {
        require(msg.value >= MIN_DEPOSIT, "Deposit too small");
        
        funderBalances[msg.sender] += msg.value;
        totalFunds += msg.value;
        
        emit FundsDeposited(msg.sender, msg.value);
    }

    function allocateBounty(uint256 issueId, uint256 amount) external override onlyFunder(amount) {
        require(SecurityUtils.validateAmount(amount, funderBalances[msg.sender]), "Invalid amount");
        require(issueBounties[issueId] == 0, "Bounty already allocated");

        funderBalances[msg.sender] -= amount;
        issueBounties[issueId] = amount;

        emit BountyAllocated(issueId, amount);
    }

    function reallocateFunds(uint256 fromIssue, uint256 toIssue, uint256 amount) external override onlyFunder(fromIssue) {
        require(issueBounties[fromIssue] >= amount, "Insufficient bounty amount");
        require(issueBounties[toIssue] == 0, "Target issue already has bounty");

        issueBounties[fromIssue] -= amount;
        issueBounties[toIssue] = amount;

        emit FundsReallocated(fromIssue, toIssue, amount);
    }

    function getIssueBounty(uint256 issueId) external view override returns (uint256) {
        return issueBounties[issueId];
    }

    function getFunderBalance(address funder) external view override returns (uint256) {
        return funderBalances[funder];
    }
}