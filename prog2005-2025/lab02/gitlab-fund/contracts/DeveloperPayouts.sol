// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IDeveloperPayouts.sol";
import "./interfaces/IFundManager.sol";
import "./interfaces/IValidatorMultiSig.sol";
import "./libraries/SecurityUtils.sol";

contract DeveloperPayouts is IDeveloperPayouts {
    using SecurityUtils for SecurityUtils.NonReentrantContext;

    SecurityUtils.NonReentrantContext private _reentrancyContext;

    struct Claim {
        address developer;
        uint256 amount;
        bool claimed;
        bool paid;
        uint256 timestamp;
    }

    IFundManager private immutable _fundManager; // Changed to private
    IValidatorMultiSig public validatorMultiSig;
    address public owner;

    mapping(uint256 => Claim) public claims;
    uint256 public constant CLAIM_TIMEOUT = 7 days;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _fundManagerAddr, address _validatorMultiSig) {
        require(_fundManagerAddr != address(0), "Invalid fund manager address");
        require(_validatorMultiSig != address(0), "Invalid validator address");
        _fundManager = IFundManager(_fundManagerAddr);
        validatorMultiSig = IValidatorMultiSig(_validatorMultiSig);
        owner = msg.sender;
    }

    // Implement the interface function to return fundManager address
    function fundManager() external view override returns (address) {
        return address(_fundManager);
    }

    function updateValidator(address _newValidator) external onlyOwner {
        require(_newValidator != address(0), "Invalid validator address");
        validatorMultiSig = IValidatorMultiSig(_newValidator);
    }

    modifier onlyUnclaimedBounty(uint256 issueId) {
        uint256 bountyAmount = _fundManager.getIssueBounty(issueId);
        require(bountyAmount > 0, "No bounty for this issue");
        
        (,,, bool active) = _fundManager.getBountyDetails(issueId);
        require(active, "Bounty is not active");
        require(!claims[issueId].claimed, "Bounty already claimed");
        _;
    }

    function claimBounty(uint256 issueId) external override onlyUnclaimedBounty(issueId) {
        uint256 bountyAmount = _fundManager.getIssueBounty(issueId);

        claims[issueId] = Claim({
            developer: msg.sender,
            amount: bountyAmount,
            claimed: true,
            paid: false,
            timestamp: block.timestamp
        });

        emit BountyClaimed(issueId, msg.sender);
    }

    function processPayout(uint256 issueId) external override {
        Claim storage claim = claims[issueId];
        require(claim.claimed, "Bounty not claimed");
        require(!claim.paid, "Bounty already paid");
        require(block.timestamp <= claim.timestamp + CLAIM_TIMEOUT, "Claim expired");

        require(validatorMultiSig.isApproved(issueId, claim.developer),
            "Not approved by validators");

        claim.paid = true;

        (bool success, ) = payable(claim.developer).call{value: claim.amount}("");
        require(success, "Transfer failed");

        emit PayoutProcessed(issueId, claim.developer, claim.amount);
    }

    function getClaimStatus(uint256 issueId)
        external
        view
        override
        returns (bool claimed, address developer, uint256 amount)
    {
        Claim storage claim = claims[issueId];
        return (claim.claimed, claim.developer, claim.amount);
    }

    function cancelClaim(uint256 issueId) external override {
        Claim storage claim = claims[issueId];
        require(claim.claimed, "Bounty not claimed");
        require(!claim.paid, "Bounty already paid");
        require(claim.developer == msg.sender, "Only claimer can cancel");

        delete claims[issueId];

        emit ClaimCancelled(issueId, msg.sender);
    }

    receive() external payable {}
}