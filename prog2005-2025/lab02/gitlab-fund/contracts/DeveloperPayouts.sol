// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IDeveloperPayouts.sol";
import "./interfaces/IFundManager.sol";
import "./interfaces/IValidatorMultiSig.sol";
import "./libraries/SecurityUtils.sol";

contract DeveloperPayouts is IDeveloperPayouts {
    using SecurityUtils for SecurityUtils.NonReentrantContext;

    SecurityUtils.NonReentrantContext private _reentrancyContext;

    // Struct to track bounty claims
    struct Claim {
        address developer;
        uint256 amount;
        bool claimed;
        bool paid;
    }

    // Reference to other contracts
    IFundManager public immutable fundManager;
    IValidatorMultiSig public immutable validatorMultiSig;

    // Mapping to track claims for each issue
    mapping(uint256 => Claim) public claims;

    // Timeout period for claims (7 days)
    uint256 public constant CLAIM_TIMEOUT = 7 days;
    
    // Mapping to track claim timestamps
    mapping(uint256 => uint256) public claimTimestamps;

    constructor(address _fundManager, address _validatorMultiSig) {
        require(_fundManager != address(0), "Invalid fund manager address");
        require(_validatorMultiSig != address(0), "Invalid validator address");
        fundManager = IFundManager(_fundManager);
        validatorMultiSig = IValidatorMultiSig(_validatorMultiSig);
    }

    modifier onlyUnclaimed(uint256 issueId) {
        require(!claims[issueId].claimed, "Issue already claimed");
        _;
    }

    modifier onlyClaimed(uint256 issueId) {
        require(claims[issueId].claimed, "Issue not claimed");
        require(!claims[issueId].paid, "Bounty already paid");
        _;
    }

    /**
     * @dev Developer claims a bounty for an issue
     * @param issueId The GitLab issue ID
     */
    function claimBounty(uint256 issueId) external override onlyUnclaimed(issueId) {
        uint256 bountyAmount = fundManager.getIssueBounty(issueId);
        require(bountyAmount > 0, "No bounty for this issue");

        claims[issueId] = Claim({
            developer: msg.sender,
            amount: bountyAmount,
            claimed: true,
            paid: false
        });
        claimTimestamps[issueId] = block.timestamp;

        emit BountyClaimed(issueId, msg.sender);
    }

    /**
     * @dev Process payout for a claimed bounty after validator approval
     * @param issueId The GitLab issue ID
     */
    function processPayout(uint256 issueId) external override onlyClaimed(issueId) {
        Claim storage claim = claims[issueId];
        
        // Check validator approval
        require(validatorMultiSig.isApproved(issueId, claim.developer), "Not approved by validators");
        
        // Check if claim hasn't expired
        require(block.timestamp <= claimTimestamps[issueId] + CLAIM_TIMEOUT, "Claim expired");

        // Mark as paid before transfer to prevent reentrancy
        claim.paid = true;

        // Transfer the bounty amount
        (bool success, ) = payable(claim.developer).call{value: claim.amount}("");
        require(success, "Transfer failed");

        emit PayoutProcessed(issueId, claim.developer, claim.amount);
    }

    /**
     * @dev Cancel a claim (can be called by the original claimer or automatically after timeout)
     * @param issueId The GitLab issue ID
     */
    function cancelClaim(uint256 issueId) external override {
        Claim storage claim = claims[issueId];
        require(claim.claimed && !claim.paid, "Invalid claim state");
        require(
            msg.sender == claim.developer || 
            block.timestamp > claimTimestamps[issueId] + CLAIM_TIMEOUT,
            "Not authorized to cancel"
        );

        delete claims[issueId];
        delete claimTimestamps[issueId];

        emit ClaimCancelled(issueId, claim.developer);
    }

    /**
     * @dev Get the current status of a claim
     * @param issueId The GitLab issue ID
     * @return claimed Whether the bounty has been claimed
     * @return developer The address of the developer who claimed
     * @return amount The bounty amount
     */
    function getClaimStatus(uint256 issueId) 
        external 
        view 
        override 
        returns (bool claimed, address developer, uint256 amount) 
    {
        Claim storage claim = claims[issueId];
        return (claim.claimed, claim.developer, claim.amount);
    }

    /**
     * @dev Check if a claim has expired
     * @param issueId The GitLab issue ID
     * @return bool Whether the claim has expired
     */
    function isClaimExpired(uint256 issueId) public view returns (bool) {
        if (!claims[issueId].claimed) return false;
        return block.timestamp > claimTimestamps[issueId] + CLAIM_TIMEOUT;
    }

    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {}
}