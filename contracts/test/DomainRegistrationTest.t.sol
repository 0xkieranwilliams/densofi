// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DomainRegistration.sol";

contract DomainRegistrationTest is Test {
    DomainRegistration public domainRegistration;
    address public owner;
    address public user1;
    address public user2;
    uint256 public initialFee = 0.01 ether;

    // Events to test
    event RegistrationRequested(
        string domainName,
        address requester,
        uint256 fee
    );
    event RegistrationFeeUpdated(uint256 newFee);

    function setUp() public {
        // Setup accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Fund accounts
        vm.deal(owner, 1 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        // Deploy contract with correct constructor parameter order
        vm.prank(owner);
        domainRegistration = new DomainRegistration(initialFee, owner);
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructor() public view {
        assertEq(domainRegistration.s_registrationFee(), initialFee);
        assertEq(domainRegistration.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRATION FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function testUpdateRegistrationFee() public {
        uint256 newFee = 0.02 ether;

        // Only owner can update fee
        vm.prank(owner);

        // Test event emission
        vm.expectEmit(true, true, true, true);
        emit RegistrationFeeUpdated(newFee);

        domainRegistration.updateRegistrationFee(newFee);
        assertEq(domainRegistration.s_registrationFee(), newFee);
    }

    function testUpdateRegistrationFeeRevertsForNonOwner() public {
        uint256 newFee = 0.02 ether;

        // User1 is not the owner
        vm.prank(user1);

        // Should revert with "Ownable: caller is not the owner"
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        domainRegistration.updateRegistrationFee(newFee);
    }

    /*//////////////////////////////////////////////////////////////
                      REQUEST REGISTRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testRequestRegistration() public {
        string memory domainName = "example.com";
        uint256 fee = initialFee;

        // Check user1 and owner balances before
        uint256 user1BalanceBefore = user1.balance;
        uint256 ownerBalanceBefore = owner.balance;

        // User1 requests registration
        vm.prank(user1);

        // Test event emission
        vm.expectEmit(true, true, true, true);
        emit RegistrationRequested(domainName, user1, fee);

        domainRegistration.requestRegistration{value: fee}(domainName);

        // Check balances after
        uint256 user1BalanceAfter = user1.balance;
        uint256 ownerBalanceAfter = owner.balance;

        // User1 should have paid the fee
        assertEq(user1BalanceBefore - user1BalanceAfter, fee);

        // Owner should have received the fee
        assertEq(ownerBalanceAfter - ownerBalanceBefore, fee);
    }

    function testRequestRegistrationWithOverpayment() public {
        string memory domainName = "example.com";
        uint256 fee = initialFee * 2; // Paying double the fee

        // Check user1 and owner balances before
        uint256 user1BalanceBefore = user1.balance;
        uint256 ownerBalanceBefore = owner.balance;

        // User1 requests registration with overpayment
        vm.prank(user1);

        // Test event emission with the overpaid amount
        vm.expectEmit(true, true, true, true);
        emit RegistrationRequested(domainName, user1, fee);

        domainRegistration.requestRegistration{value: fee}(domainName);

        // Check balances after
        uint256 user1BalanceAfter = user1.balance;
        uint256 ownerBalanceAfter = owner.balance;

        // User1 should have paid the overpaid fee amount
        assertEq(user1BalanceBefore - user1BalanceAfter, fee);

        // Owner should have received the full amount (including overpayment)
        assertEq(ownerBalanceAfter - ownerBalanceBefore, fee);
    }

    function testRequestRegistrationRevertsWithEmptyDomain() public {
        string memory domainName = "";
        uint256 fee = initialFee;

        // User1 tries to register empty domain name
        vm.prank(user1);

        // Should revert with custom error message
        vm.expectRevert("Domain name cannot be empty");
        domainRegistration.requestRegistration{value: fee}(domainName);
    }

    function testRequestRegistrationRevertsWithInsufficientFee() public {
        string memory domainName = "example.com";
        uint256 fee = initialFee - 0.001 ether; // Less than required fee

        // User1 tries to register with insufficient fee
        vm.prank(user1);

        // Should revert with custom error message
        vm.expectRevert("Insufficient fee");
        domainRegistration.requestRegistration{value: fee}(domainName);
    }

    /*//////////////////////////////////////////////////////////////
                     FEE FORWARDING EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function testRegistrationFailsWhenForwardingFails() public {
        // Create a malicious contract that rejects ETH
        MaliciousOwner maliciousOwner = new MaliciousOwner();

        // Transfer ownership to the malicious contract
        vm.prank(owner);
        domainRegistration.transferOwnership(address(maliciousOwner));

        // Try to register a domain
        string memory domainName = "example.com";
        vm.prank(user1);

        // Should revert because the malicious owner rejects ETH
        vm.expectRevert("Failed to forward fee to admin wallet");
        domainRegistration.requestRegistration{value: initialFee}(domainName);
    }

    /*//////////////////////////////////////////////////////////////
                      MULTIPLE REGISTRATIONS TEST
    //////////////////////////////////////////////////////////////*/

    function testMultipleRegistrations() public {
        // This tests the contract allowing multiple registrations of the same domain
        // which is valid in this architecture since the backend handles uniqueness

        string memory domainName = "example.com";

        // User1 registers first
        vm.prank(user1);
        domainRegistration.requestRegistration{value: initialFee}(domainName);

        // User2 can register the same domain (backend would handle preventing this)
        vm.prank(user2);
        domainRegistration.requestRegistration{value: initialFee}(domainName);

        // Both registrations should succeed at the contract level
        // (This is acceptable because the backend restricts duplicate registrations)
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_RequestRegistration(
        string calldata domainName,
        uint256 paymentAmount
    ) public {
        // Skip if domain name is empty
        vm.assume(bytes(domainName).length > 0);

        // Cap the payment amount to avoid overflow
        paymentAmount = bound(paymentAmount, initialFee, 100 ether);

        // Ensure user has enough balance
        vm.deal(user1, paymentAmount + 1 ether);

        // Owner's balance before
        uint256 ownerBalanceBefore = owner.balance;

        // User1 requests registration
        vm.prank(user1);
        domainRegistration.requestRegistration{value: paymentAmount}(
            domainName
        );

        // Check owner received the payment
        assertEq(owner.balance - ownerBalanceBefore, paymentAmount);
    }

    function testFuzz_UpdateRegistrationFee(uint256 newFee) public {
        // Bound to reasonable values
        newFee = bound(newFee, 0, 100 ether);

        // Owner updates fee
        vm.prank(owner);
        domainRegistration.updateRegistrationFee(newFee);

        // Check fee was updated
        assertEq(domainRegistration.s_registrationFee(), newFee);
    }
}

// Helper contract for testing edge cases
contract MaliciousOwner {
    // This contract rejects all ETH transfers
    fallback() external payable {
        revert("I reject all ETH");
    }

    receive() external payable {
        revert("I reject all ETH");
    }
}
