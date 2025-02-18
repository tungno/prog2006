// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IValidatorMultiSig.sol";
import "./libraries/SecurityUtils.sol";

contract ValidatorMultiSig is IValidatorMultiSig {
    using SecurityUtils for SecurityUtils.NonReentrantContext;

    SecurityUtils.NonReentrantContext private _reentrancyContext;

    // Array of validator addresses
    address[] public validators;
    
    // Required number of approvals
    uint256 public threshold;
    
    // Mapping to track validator status
    mapping(address => bool) public isValidator;
    
    // Mapping to track approvals: issueId => developer => validator => approved
    mapping(uint256 => mapping(address => mapping(address => bool))) public approvals;
    
    // Mapping to track approval counts: issueId => developer => count
    mapping(uint256 => mapping(address => uint256)) public approvalCounts;

    constructor(address[] memory _validators, uint256 _threshold) {
        require(_validators.length >= _threshold, "Threshold too high");
        require(_threshold > 0, "Threshold too low");
        require(SecurityUtils.validateAddresses(_validators), "Invalid validators");

        for (uint i = 0; i < _validators.length; i++) {
            validators.push(_validators[i]);
            isValidator[_validators[i]] = true;
        }
        threshold = _threshold;
    }

    modifier onlyValidator() {
        require(isValidator[msg.sender], "Not a validator");
        _;
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
        require(!approvals[issueId][developer][msg.sender], "Already approved");

        approvals[issueId][developer][msg.sender] = true;
        approvalCounts[issueId][developer]++;

        emit PayoutApproved(issueId, developer);
    }

    function revokeApproval(uint256 issueId, address developer) external override onlyValidator {
        require(approvals[issueId][developer][msg.sender], "Not approved");

        approvals[issueId][developer][msg.sender] = false;
        approvalCounts[issueId][developer]--;
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
}