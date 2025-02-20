// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IFundManager.sol";
import "./libraries/SecurityUtils.sol";

/**
 * @title FundManager
 * @notice Manages funding and bounty allocation for GitLab issues
 * @dev Tracks detailed balance information and ensures secure fund management
 */
contract FundManager is IFundManager {
    using SecurityUtils for SecurityUtils.NonReentrantContext;

    SecurityUtils.NonReentrantContext private _reentrancyContext;

    struct FunderInfo {
        uint256 totalDeposited;     // Total amount ever deposited
        uint256 currentBalance;     // Current available balance
        uint256 totalAllocated;     // Total amount allocated to bounties
        uint256 activeBounties;     // Number of active bounties
    }

    struct BountyInfo {
        uint256 amount;            // Bounty amount
        address funder;            // Address of the funder
        uint256 createdAt;        // When the bounty was created
        bool active;              // Whether the bounty is still active
    }

    mapping(address => FunderInfo) public funderInfo;
    mapping(uint256 => BountyInfo) public bountyInfo;
    
    uint256 public totalFunds;
    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant MAX_BOUNTY_DURATION = 30 days;

    modifier enoughBalance(uint256 amount) {
        require(funderInfo[msg.sender].currentBalance >= amount, "Insufficient balance");
        _;
    }

    modifier validBounty(uint256 issueId) {
        require(bountyInfo[issueId].active, "Bounty not active");
        _;
    }

    receive() external payable {
        depositFunds();
    }

    function depositFunds() public payable override {
        require(msg.value >= MIN_DEPOSIT, "Deposit too small");
        
        FunderInfo storage funder = funderInfo[msg.sender];
        funder.totalDeposited += msg.value;
        funder.currentBalance += msg.value;
        totalFunds += msg.value;
        
        emit FundsDeposited(msg.sender, msg.value);
    }

    function allocateBounty(uint256 issueId, uint256 amount) 
        external 
        override 
        enoughBalance(amount) 
    {
        require(amount > 0, "Amount must be positive");
        require(bountyInfo[issueId].amount == 0, "Bounty already exists");
        
        FunderInfo storage funder = funderInfo[msg.sender];
        funder.currentBalance -= amount;
        funder.totalAllocated += amount;
        funder.activeBounties++;

        bountyInfo[issueId] = BountyInfo({
            amount: amount,
            funder: msg.sender,
            createdAt: block.timestamp,
            active: true
        });

        emit BountyAllocated(issueId, amount);
    }

    function reallocateFunds(uint256 fromIssue, uint256 toIssue, uint256 amount) 
        external 
        override 
        validBounty(fromIssue) 
    {
        BountyInfo storage fromBounty = bountyInfo[fromIssue];
        require(msg.sender == fromBounty.funder, "Not bounty funder");
        require(fromBounty.amount >= amount, "Insufficient bounty amount");
        require(bountyInfo[toIssue].amount == 0, "Target issue already has bounty");

        fromBounty.amount -= amount;
        if (fromBounty.amount == 0) {
            fromBounty.active = false;
            FunderInfo storage funder = funderInfo[msg.sender];
            funder.activeBounties--;
        }

        bountyInfo[toIssue] = BountyInfo({
            amount: amount,
            funder: msg.sender,
            createdAt: block.timestamp,
            active: true
        });

        emit FundsReallocated(fromIssue, toIssue, amount);
    }

    function cancelBounty(uint256 issueId) external validBounty(issueId) {
        BountyInfo storage bounty = bountyInfo[issueId];
        require(msg.sender == bounty.funder, "Not bounty funder");
        
        FunderInfo storage funder = funderInfo[msg.sender];
        funder.currentBalance += bounty.amount;
        funder.totalAllocated -= bounty.amount;
        funder.activeBounties--;
        
        bounty.active = false;
        
        emit BountyCancelled(issueId);
    }

    function getFunderDetails(address funder) 
        external 
        view 
        returns (
            uint256 totalDeposited,
            uint256 currentBalance,
            uint256 totalAllocated,
            uint256 activeBounties
        ) 
    {
        FunderInfo memory info = funderInfo[funder];
        return (
            info.totalDeposited,
            info.currentBalance,
            info.totalAllocated,
            info.activeBounties
        );
    }

    function getBountyDetails(uint256 issueId)
        external
        view
        returns (
            uint256 amount,
            address funder,
            uint256 createdAt,
            bool active
        )
    {
        BountyInfo memory info = bountyInfo[issueId];
        return (
            info.amount,
            info.funder,
            info.createdAt,
            info.active
        );
    }

    function getIssueBounty(uint256 issueId) external view override returns (uint256) {
    BountyInfo memory bounty = bountyInfo[issueId];
    // Return 0 if bounty is not active
    if (!bounty.active) {
        return 0;
    }
    return bounty.amount;
}

    function getFunderBalance(address funder) external view override returns (uint256) {
        return funderInfo[funder].currentBalance;
    }
}