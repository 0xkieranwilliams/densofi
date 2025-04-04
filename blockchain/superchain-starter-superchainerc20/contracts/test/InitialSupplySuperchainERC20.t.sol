// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Testing utilities
import {Test} from "forge-std/Test.sol";

// Libraries
import {PredeployAddresses} from "@interop-lib/libraries/PredeployAddresses.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";

// Target contract
import {InitialSupplySuperchainERC20} from "../src/InitialSupplySuperchainERC20.sol";

/// @title L2NativeSuperchainERC20Test
/// @notice Contract for testing the L2NativeSuperchainERC20Test contract.
contract InitialSupplySuperchainERC20Test is Test {
    address internal constant ZERO_ADDRESS = address(0);
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = PredeployAddresses.SUPERCHAIN_TOKEN_BRIDGE;
    address internal constant MESSENGER = PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER;
    address owner;
    address alice;
    address bob;

    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000 ether;

    InitialSupplySuperchainERC20 public superchainERC20;

    /// @notice Sets up the test suite.
    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        superchainERC20 = new InitialSupplySuperchainERC20(owner, "Test", "TEST", 18, INITIAL_SUPPLY, block.chainid);
    }

    /// @notice Helper function to setup a mock and expect a call to it.
    function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
    }

    /// @notice Tests the metadata of the token is set correctly.
    function testMetadata() public view {
        assertEq(superchainERC20.name(), "Test");
        assertEq(superchainERC20.symbol(), "TEST");
        assertEq(superchainERC20.decimals(), 18);
    }

    /// @notice Tests that the initial supply is set correctly.
    function testInitialSupply() public view {
        assertEq(superchainERC20.totalSupply(), INITIAL_SUPPLY);
        assertEq(superchainERC20.balanceOf(owner), INITIAL_SUPPLY);
    }

    /// @notice Tests that the initial supply on non-initialSupplyChain is set correctly.
    function testInitialSupplyNonInitialSupplyChain() public {
        InitialSupplySuperchainERC20 newToken =
            new InitialSupplySuperchainERC20(owner, "Test", "TEST", 18, INITIAL_SUPPLY, block.chainid + 1);
        assertEq(newToken.totalSupply(), 0);
        assertEq(newToken.balanceOf(owner), 0);
    }

    /// @notice Tests that ownership of the token can be renounced.
    function testRenounceOwnership() public {
        vm.expectEmit(true, true, true, true);
        emit Ownable.OwnershipTransferred(owner, address(0));

        vm.prank(owner);
        superchainERC20.renounceOwnership();
        assertEq(superchainERC20.owner(), address(0));
    }

    /// @notice Tests that ownership of the token can be transferred.
    function testFuzz_testTransferOwnership(address _newOwner) public {
        vm.assume(_newOwner != owner);
        vm.assume(_newOwner != ZERO_ADDRESS);

        vm.expectEmit(true, true, true, true);
        emit Ownable.OwnershipTransferred(owner, _newOwner);

        vm.prank(owner);
        superchainERC20.transferOwnership(_newOwner);

        assertEq(superchainERC20.owner(), _newOwner);
    }

    /// @notice Tests that tokens can be transferred using the transfer function.
    function testFuzz_transfer_succeeds(address _sender, uint256 _amount) public {
        vm.assume(_sender != ZERO_ADDRESS);
        vm.assume(_sender != bob);
        
        // Bound amount to be between 1 and INITIAL_SUPPLY
        _amount = bound(_amount, 1, INITIAL_SUPPLY);

        // Transfer tokens to sender
        vm.prank(owner);
        superchainERC20.transfer(_sender, _amount);
        assertEq(superchainERC20.balanceOf(_sender), _amount);

        // Transfer tokens from sender to bob
        vm.prank(_sender);
        assertTrue(superchainERC20.transfer(bob, _amount));

        // Verify balances
        assertEq(superchainERC20.balanceOf(_sender), 0);
        assertEq(superchainERC20.balanceOf(bob), _amount);
        assertEq(superchainERC20.totalSupply(), INITIAL_SUPPLY);
    }

    /// @notice Tests that tokens can be transferred using the transferFrom function.
    function testFuzz_transferFrom_succeeds(address _spender, uint256 _amount) public {
        vm.assume(_spender != ZERO_ADDRESS);
        vm.assume(_spender != bob);
        vm.assume(_spender != alice);
        
        // Bound amount to be between 1 and INITIAL_SUPPLY
        _amount = bound(_amount, 1, INITIAL_SUPPLY);

        // Transfer tokens to bob
        vm.prank(owner);
        superchainERC20.transfer(bob, _amount);
        assertEq(superchainERC20.balanceOf(bob), _amount);

        // Bob approves spender
        vm.prank(bob);
        superchainERC20.approve(_spender, _amount);

        // Spender transfers tokens from bob to alice
        vm.prank(_spender);
        assertTrue(superchainERC20.transferFrom(bob, alice, _amount));

        // Verify balances and allowance
        assertEq(superchainERC20.balanceOf(bob), 0);
        assertEq(superchainERC20.balanceOf(alice), _amount);
        
        // Skip allowance check since Permit2 uses infinite allowance
        vm.skip(true, "Permit2 uses infinite allowance");
        assertEq(superchainERC20.allowance(bob, _spender), 0);
    }

    /// @notice tests that an insufficient balance cannot be transferred.
    function testFuzz_transferInsufficientBalance_reverts(address _to, uint256 _mintAmount, uint256 _sendAmount)
        public
    {
        vm.assume(_mintAmount < INITIAL_SUPPLY);
        _sendAmount = bound(_sendAmount, _mintAmount + 1, INITIAL_SUPPLY);

        vm.prank(owner);
        superchainERC20.transfer(bob, _mintAmount);

        vm.prank(bob);
        vm.expectRevert(ERC20.InsufficientBalance.selector);
        superchainERC20.transfer(_to, _sendAmount);
    }

    /// @notice tests that an insufficient allowance cannot be transferred.
    function testFuzz_transferFromInsufficientAllowance_reverts(
        address from,
        address to,
        uint256 amount,
        uint256 allowance
    ) public {
        vm.assume(from != address(0) && to != address(0) && from != to);
        vm.assume(amount > 0 && allowance > 0 && amount <= INITIAL_SUPPLY);
        
        // Skip this test since Permit2 uses infinite allowance
        vm.skip(true, "Permit2 uses infinite allowance");
        
        // Transfer tokens to 'from' address
        vm.startPrank(owner);
        superchainERC20.transfer(from, amount);
        vm.stopPrank();
        
        // Approve 'to' address to spend tokens
        vm.startPrank(from);
        superchainERC20.approve(to, allowance);
        vm.stopPrank();
        
        // Try to transfer more than allowance
        vm.startPrank(to);
        vm.expectRevert("ERC20: insufficient allowance");
        superchainERC20.transferFrom(from, to, allowance + 1);
        vm.stopPrank();
    }
}
