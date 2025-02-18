// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IValidatorMultiSig {
    // Events
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event PayoutApproved(uint256 indexed issueId, address indexed developer);
    event ThresholdChanged(uint256 newThreshold);

    // Functions
    function addValidator(address validator) external;
    function removeValidator(address validator) external;
    function approvePayment(uint256 issueId, address developer) external;
    function revokeApproval(uint256 issueId, address developer) external;
    function isApproved(uint256 issueId, address developer) external view returns (bool);
    function getApprovalCount(uint256 issueId, address developer) external view returns (uint256);
    function getValidators() external view returns (address[] memory);
}