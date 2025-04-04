// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Testing utilities
import {Test} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

// Target contract
import {NFTMinter} from "../src/NFTMinter.sol";
import {IResolver} from "../src/NFTMinter.sol";

// Helper contract to make addresses ERC1155 receivers
contract ERC1155ReceiverHelper is IERC1155Receiver {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
    
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}

/// @title NFTMinterTest
/// @notice Contract for testing the NFTMinter contract.
contract NFTMinterTest is Test {
    NFTMinter public nftMinter;
    address public owner;
    address public alice;
    address public bob;
    ERC1155ReceiverHelper public aliceHelper;
    ERC1155ReceiverHelper public bobHelper;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @notice Sets up the test suite.
    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        aliceHelper = new ERC1155ReceiverHelper();
        bobHelper = new ERC1155ReceiverHelper();
        
        vm.startPrank(owner);
        nftMinter = new NFTMinter();
        vm.stopPrank();
    }
    
    /// @notice Tests that the deployment sets the right owner.
    function test_deployment_setsRightOwner() public view {
        assertTrue(nftMinter.hasRole(DEFAULT_ADMIN_ROLE, owner));
    }
    
    /// @notice Tests that the deployment assigns the minter role to the owner.
    function test_deployment_assignsMinterRole() public view {
        assertTrue(nftMinter.hasRole(MINTER_ROLE, owner));
    }
    
    /// @notice Tests that minting an NFT sets the correct name.
    function test_mint_setsCorrectName() public {
        vm.startPrank(owner);
        uint256 tokenId = nftMinter.mint("Test NFT");
        vm.stopPrank();
        
        assertEq(nftMinter.tokenName(tokenId), "Test NFT");
    }
    
    /// @notice Tests that minting an NFT increments the token ID counter.
    function test_mint_incrementsTokenId() public {
        vm.startPrank(owner);
        uint256 tokenId1 = nftMinter.mint("NFT 1");
        uint256 tokenId2 = nftMinter.mint("NFT 2");
        vm.stopPrank();
        
        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
    }
    
    /// @notice Tests that non-minter cannot mint NFTs.
    function test_mint_nonMinterCannotMint() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                alice,
                MINTER_ROLE
            )
        );
        nftMinter.mint("Test NFT");
        vm.stopPrank();
    }
    
    /// @notice Tests that the URI is correctly formatted.
    function test_uri_returnsCorrectFormat() public {
        vm.startPrank(owner);
        uint256 tokenId = nftMinter.mint("Test NFT");
        vm.stopPrank();
        
        assertEq(nftMinter.uri(tokenId), "ipfs://0");
    }
    
    /// @notice Tests that tokens can be transferred.
    function test_transfer_succeeds() public {
        vm.startPrank(owner);
        uint256 tokenId = nftMinter.mint("Test NFT");
        nftMinter.safeTransferFrom(owner, alice, tokenId, 1, "");
        vm.stopPrank();
        
        assertEq(nftMinter.balanceOf(alice, tokenId), 1);
    }
    
    /// @notice Tests that transferring without approval reverts.
    function test_transfer_noApproval_reverts() public {
        vm.startPrank(owner);
        uint256 tokenId = nftMinter.mint("Test NFT");
        vm.stopPrank();
        
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC1155MissingApprovalForAll(address,address)",
                alice,
                owner
            )
        );
        nftMinter.safeTransferFrom(owner, bob, tokenId, 1, "");
        vm.stopPrank();
    }
    
    /// @notice Tests that the minter role can be granted.
    function test_grantRole_succeeds() public {
        vm.startPrank(owner);
        nftMinter.grantRole(MINTER_ROLE, alice);
        vm.stopPrank();
        
        assertTrue(nftMinter.hasRole(MINTER_ROLE, alice));
    }
    
    /// @notice Tests that only admin can grant roles.
    function test_grantRole_nonAdmin_reverts() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                alice,
                DEFAULT_ADMIN_ROLE
            )
        );
        nftMinter.grantRole(MINTER_ROLE, bob);
        vm.stopPrank();
    }
    
    /// @notice Tests that the minter role can be revoked.
    function test_revokeRole_succeeds() public {
        vm.startPrank(owner);
        nftMinter.grantRole(MINTER_ROLE, alice);
        nftMinter.revokeRole(MINTER_ROLE, alice);
        vm.stopPrank();
        
        assertFalse(nftMinter.hasRole(MINTER_ROLE, alice));
    }
    
    /// @notice Tests that only admin can revoke roles.
    function test_revokeRole_nonAdmin_reverts() public {
        vm.startPrank(owner);
        nftMinter.grantRole(MINTER_ROLE, alice);
        vm.stopPrank();
        
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                alice,
                DEFAULT_ADMIN_ROLE
            )
        );
        nftMinter.revokeRole(MINTER_ROLE, alice);
        vm.stopPrank();
    }
    
    /// @notice Tests that minting emits the NFTMinted event.
    function test_mint_emitsEvent() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit NFTMinter.NFTMinted(0, owner, "Test NFT");
        uint256 tokenId = nftMinter.mint("Test NFT");
        vm.stopPrank();
        
        assertEq(tokenId, 0);
    }
    
    /// @notice Tests that minting via resolver succeeds when caller owns the domain
    function test_mintViaResolver_succeeds() public {
        // Mock the resolver to return the owner address for the domain
        bytes32 nameHash = nftMinter.stringToBytes32("test.eth");
        vm.mockCall(
            nftMinter.RESOLVER(),
            abi.encodeWithSelector(IResolver.owner.selector, nameHash),
            abi.encode(owner)
        );
        
        // Mint as owner
        vm.startPrank(owner);
        uint256 tokenId = nftMinter.mintViaResolver("test.eth");
        vm.stopPrank();
        
        // Verify the token was minted correctly
        assertEq(tokenId, 0);
        assertEq(nftMinter.tokenName(tokenId), "test.eth");
        assertEq(nftMinter.balanceOf(owner, tokenId), 1);
    }
    
    /// @notice Tests that minting via resolver reverts when caller doesn't own the domain
    function test_mintViaResolver_notOwner_reverts() public {
        // Mock the resolver to return a different address for the domain
        bytes32 nameHash = nftMinter.stringToBytes32("test.eth");
        vm.mockCall(
            nftMinter.RESOLVER(),
            abi.encodeWithSelector(IResolver.owner.selector, nameHash),
            abi.encode(alice)
        );
        
        // Try to mint as owner (who doesn't own the domain)
        vm.startPrank(owner);
        vm.expectRevert("Must own domain");
        nftMinter.mintViaResolver("test.eth");
        vm.stopPrank();
    }
    
    /// @notice Tests that stringToBytes32 converts strings correctly
    function test_stringToBytes32_convertsCorrectly() public {
        string memory testString = "test.eth";
        bytes32 expected = bytes32(bytes(testString));
        assertEq(nftMinter.stringToBytes32(testString), expected);
        
        // Test empty string
        assertEq(nftMinter.stringToBytes32(""), bytes32(0));
    }
} 