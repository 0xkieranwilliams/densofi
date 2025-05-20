// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Domain Registration Contract
/// @notice This contract allows users to request domain name registrations and ownership updates by paying a fee
/// @dev Inherits OpenZeppelin's Ownable contract for access control
contract DomainRegistration is Ownable {
    /// @notice The fee required to request a domain registration
    uint256 public s_registrationFee;
    
    /// @notice The fee required to request a domain ownership update
    uint256 public s_ownershipUpdateFee;

    /// @notice Emitted when a user requests a domain registration
    /// @param domainName The name of the domain being requested
    /// @param requester Address of the user requesting the domain
    /// @param fee Amount paid for the registration request
    event RegistrationRequested(string domainName, address requester, uint256 fee);
    
    /// @notice Emitted when a user requests an ownership update for a domain
    /// @param domainName The name of the domain to update ownership for
    /// @param requester Address of the user requesting the ownership update
    /// @param fee Amount paid for the ownership update request
    event OwnershipUpdateRequested(string domainName, address requester, uint256 fee);

    /// @notice Emitted when the registration fee is updated
    /// @param newFee The updated registration fee amount
    event RegistrationFeeUpdated(uint256 newFee);
    
    /// @notice Emitted when the ownership update fee is updated
    /// @param newFee The updated ownership update fee amount
    event OwnershipUpdateFeeUpdated(uint256 newFee);

    /// @notice Emitted when fees are forwarded to the contract owner
    /// @param to Address receiving the forwarded fees
    /// @param amount Amount of fees being forwarded
    event FeeForwarded(address indexed to, uint256 amount);

    /// @notice Initializes the contract with registration and ownership update fees
    /// @dev Sets the initial owner and fees
    /// @param initialFee The initial fee required for domain registration and ownership updates
    constructor(uint256 initialFee) Ownable(msg.sender) {
        s_registrationFee = initialFee;
        s_ownershipUpdateFee = initialFee; // Set ownership update fee same as registration fee initially
    }

    /// @notice Request the registration of a domain name
    /// @dev Forwards the registration fee to the contract owner
    /// @param domainName The name of the domain to register
    function requestRegistration(string memory domainName) public payable {
        require(bytes(domainName).length > 0, "Domain name cannot be empty");
        require(msg.value >= s_registrationFee, "Insufficient fee");
        
        emit RegistrationRequested(domainName, msg.sender, msg.value);
        
        (bool forwardSuccess, ) = payable(owner()).call{value: msg.value}("");
        require(forwardSuccess, "Failed to forward fee to admin wallet");
    }
    
    /// @notice Request an update to the ownership of a domain name
    /// @dev Forwards the ownership update fee to the contract owner
    /// @param domainName The name of the domain to update ownership for
    function requestDomainOwnershipUpdate(string memory domainName) public payable {
        require(bytes(domainName).length > 0, "Domain name cannot be empty");
        require(msg.value >= s_ownershipUpdateFee, "Insufficient fee");
        
        emit OwnershipUpdateRequested(domainName, msg.sender, msg.value);
        
        (bool forwardSuccess, ) = payable(owner()).call{value: msg.value}("");
        require(forwardSuccess, "Failed to forward fee to admin wallet");
    }

    /// @notice Update the registration fee
    /// @dev Can only be called by the contract owner
    /// @param newFee The new fee amount to set
    function updateRegistrationFee(uint256 newFee) public onlyOwner {
        s_registrationFee = newFee;
        emit RegistrationFeeUpdated(newFee);
    }
    
    /// @notice Update the ownership update fee
    /// @dev Can only be called by the contract owner
    /// @param newFee The new fee amount to set
    function updateOwnershipUpdateFee(uint256 newFee) public onlyOwner {
        s_ownershipUpdateFee = newFee;
        emit OwnershipUpdateFeeUpdated(newFee);
    }
}
