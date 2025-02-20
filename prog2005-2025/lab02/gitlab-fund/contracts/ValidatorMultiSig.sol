// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./interfaces/IFundManager.sol"; 
import "./interfaces/IValidatorMultiSig.sol";
import "./interfaces/IDeveloperPayouts.sol";
import "./libraries/SecurityUtils.sol";

/**
 * @title ValidatorMultiSig
 * @notice Implements n-out-of-m multisignature validation for bounty payouts
 * @dev Ensures secure validation process with multiple required approvals
 */
contract ValidatorMultiSig is IValidatorMultiSig {
    using SecurityUtils for SecurityUtils.NonReentrantContext;

    SecurityUtils.NonReentrantContext private _reentrancyContext;

    // Contract references
    IDeveloperPayouts public immutable developerPayouts;
    
    // Validator data structures
    address[] public validators;
    uint256 public threshold;
    
    // Mappings for tracking validator status and approvals
    mapping(address => bool) public isValidator;
    mapping(uint256 => mapping(address => mapping(address => bool))) public approvals;
    mapping(uint256 => mapping(address => uint256)) public approvalCounts;
    mapping(address => uint256) public validatorActivityCount;

    modifier onlyValidator() {
        require(isValidator[msg.sender], "Not a validator");
        _;
    }

    constructor(
        address[] memory _validators, 
        uint256 _threshold,
        address _developerPayouts
    ) {
        require(_validators.length >= _threshold, "Threshold too high");
        require(_threshold > 0, "Threshold too low");
        require(SecurityUtils.validateAddresses(_validators), "Invalid validators");
        require(_developerPayouts != address(0), "Invalid developer payouts address");

        developerPayouts = IDeveloperPayouts(_developerPayouts);

        for (uint i = 0; i < _validators.length; i++) {
            validators.push(_validators[i]);
            isValidator[_validators[i]] = true;
        }
        threshold = _threshold;
    }

    function addValidator(address validator) external override onlyValidator {
        require(!isValidator[validator], "Already a validator");
        require(validator != address(0), "Invalid address");

        validators.push(validator);
        isValidator[validator] = true;

        emit ValidatorAdded(validator);
    }

    function removeValidator(address validator) external override onlyValidator {
        require(isValidator[validator], "Not a validator");
        require(validators.length > threshold, "Cannot remove: threshold");

        isValidator[validator] = false;
        for (uint i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();
                break;
            }
        }

        emit ValidatorRemoved(validator);
    }

     function approvePayment(uint256 issueId, address developer) external override onlyValidator {
        // Verify claim exists and is valid
        (bool claimed, address claimDeveloper, uint256 amount) = developerPayouts.getClaimStatus(issueId);
        require(claimed, "No claim exists for this issue");
        require(claimDeveloper == developer, "Developer address doesn't match claim");
        require(amount > 0, "Invalid claim amount");

        // Check if bounty exists and is active in FundManager
        (uint256 bountyAmount,,,bool active) = IFundManager(developerPayouts.fundManager()).getBountyDetails(issueId);
        require(bountyAmount > 0 && active, "Invalid or inactive bounty");

        // Check double approval
        require(!approvals[issueId][developer][msg.sender], "Already approved");

        // Record approval
        approvals[issueId][developer][msg.sender] = true;
        approvalCounts[issueId][developer]++;
        validatorActivityCount[msg.sender]++;

        emit PayoutApproved(issueId, developer);
    }

    function revokeApproval(uint256 issueId, address developer) external override onlyValidator {
        require(approvals[issueId][developer][msg.sender], "Not previously approved");
        
        approvals[issueId][developer][msg.sender] = false;
        approvalCounts[issueId][developer]--;
        validatorActivityCount[msg.sender]--;

        emit ApprovalRevoked(issueId, developer);
    }

    function isApproved(uint256 issueId, address developer) external view override returns (bool) {
        return approvalCounts[issueId][developer] >= threshold;
    }

    function getApprovalCount(uint256 issueId, address developer) external view override returns (uint256) {
        return approvalCounts[issueId][developer];
    }

    function getValidators() external view override returns (address[] memory) {
        return validators;
    }

    function getValidatorStatus(address validator) external view returns (
        bool isActive,
        uint256 totalApprovals
    ) {
        return (isValidator[validator], validatorActivityCount[validator]);
    }
}