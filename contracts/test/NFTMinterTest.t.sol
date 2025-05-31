// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFTMinter.sol";
import "../src/libraries/StringBytes32.sol";

contract NFTMinterTest is Test {
    using StringBytes32 for string;
    using StringBytes32 for bytes32;

    NFTMinter public nftMinter;
    address public owner;
    address public user1;
    address public user2;

    // Test domain names
    string constant DOMAIN_1 = "example.com";
    string constant DOMAIN_2 = "test.eth";
    string constant LONG_DOMAIN = "long-domain-name-test.com"; // Must be 32 bytes or less

    // Events to test
    event NFTMinted(
        uint256 indexed tokenId,
        address indexed to,
        bytes32 domainNameHash,
        string domainName
    );
    event DomainOwnerSet(
        bytes32 indexed domainNameHash,
        address owner,
        string domainName
    );
    event DomainMintableStatusSet(
        bytes32 indexed domainNameHash,
        bool isMintable,
        string domainName
    );
    event DomainNFTMintedStatusSet(
        bytes32 indexed domainNameHash,
        bool isMinted,
        string domainName
    );

    function setUp() public {
        // Setup accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Fund accounts
        vm.deal(owner, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        // Deploy contract as owner
        vm.prank(owner);
        nftMinter = new NFTMinter(owner);
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructor() public view {
        assertEq(nftMinter.s_tokenCounter(), 0);
        assertEq(nftMinter.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                      DOMAIN REGISTRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetDomainNameToOwner() public {
        bytes32 domainHash = DOMAIN_1.stringToBytes32();

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DomainOwnerSet(domainHash, user1, DOMAIN_1);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);

        assertEq(nftMinter.getDomainOwner(DOMAIN_1), user1);
    }

    function testSetDomainNameToOwnerRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);
    }

    function testSetIsDomainMintable() public {
        bytes32 domainHash = DOMAIN_1.stringToBytes32();

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DomainMintableStatusSet(domainHash, true, DOMAIN_1);
        nftMinter.setIsDomainMintable(DOMAIN_1, true);

        assertTrue(nftMinter.isDomainMintable(DOMAIN_1));
    }

    function testSetIsDomainMintableRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        nftMinter.setIsDomainMintable(DOMAIN_1, true);
    }

    function testSetIsDomainNFTMinted() public {
        bytes32 domainHash = DOMAIN_1.stringToBytes32();

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DomainNFTMintedStatusSet(domainHash, true, DOMAIN_1);
        nftMinter.setIsDomainNFTMinted(DOMAIN_1, true);
    }

    /*//////////////////////////////////////////////////////////////
                          NFT MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function testMintDomainNFT() public {
        // Setup domain for minting
        bytes32 domainHash = DOMAIN_1.stringToBytes32();

        vm.startPrank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);
        nftMinter.setIsDomainMintable(DOMAIN_1, true);
        vm.stopPrank();

        // Mint the NFT
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit NFTMinted(1, user1, domainHash, DOMAIN_1);
        uint256 tokenId = nftMinter.mintDomainNFT(DOMAIN_1);

        // Verify results
        assertEq(tokenId, 1);
        assertEq(nftMinter.s_tokenCounter(), 1);
        assertEq(nftMinter.s_domainNameToTokenId(domainHash), 1);
        assertEq(nftMinter.s_tokenIdToDomainName(1), domainHash);
        assertTrue(nftMinter.s_isDomainNFTMinted(domainHash));
        assertEq(nftMinter.balanceOf(user1, 1), 1);
    }

    function testMintDomainNFTWithLongDomainName() public {
        vm.startPrank(owner);
        nftMinter.setDomainNameToOwner(LONG_DOMAIN, user1);
        nftMinter.setIsDomainMintable(LONG_DOMAIN, true);
        vm.stopPrank();

        // Mint the NFT
        vm.prank(user1);
        uint256 tokenId = nftMinter.mintDomainNFT(LONG_DOMAIN);

        // Verify results
        assertEq(tokenId, 1);
        string memory recoveredDomain = nftMinter.getTokenNameFromId(tokenId);

        // Check if the conversion works correctly with the library
        assertEq(recoveredDomain, LONG_DOMAIN);
    }

    function testMintDomainNFTRevertsForNonOwner() public {
        // Setup domain for minting
        vm.startPrank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);
        nftMinter.setIsDomainMintable(DOMAIN_1, true);
        vm.stopPrank();

        // Try to mint as non-owner of the domain
        vm.prank(user2);
        vm.expectRevert("Caller is not the domain owner");
        nftMinter.mintDomainNFT(DOMAIN_1);
    }

    function testMintDomainNFTRevertsWhenNotMintable() public {
        // Setup domain ownership but don't make it mintable
        vm.prank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);

        // Try to mint
        vm.prank(user1);
        vm.expectRevert("Domain not available for minting");
        nftMinter.mintDomainNFT(DOMAIN_1);
    }

    function testMintDomainNFTRevertsWhenAlreadyMinted() public {
        // Setup domain for minting
        vm.startPrank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);
        nftMinter.setIsDomainMintable(DOMAIN_1, true);
        vm.stopPrank();

        // Mint once
        vm.prank(user1);
        nftMinter.mintDomainNFT(DOMAIN_1);

        // Try to mint again
        vm.prank(user1);
        vm.expectRevert("Domain NFT already minted");
        nftMinter.mintDomainNFT(DOMAIN_1);
    }

    function testCanMintMultipleDomains() public {
        // Setup two domains for minting
        vm.startPrank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);
        nftMinter.setIsDomainMintable(DOMAIN_1, true);
        nftMinter.setDomainNameToOwner(DOMAIN_2, user1);
        nftMinter.setIsDomainMintable(DOMAIN_2, true);
        vm.stopPrank();

        // Mint both domains
        vm.startPrank(user1);
        uint256 tokenId1 = nftMinter.mintDomainNFT(DOMAIN_1);
        uint256 tokenId2 = nftMinter.mintDomainNFT(DOMAIN_2);
        vm.stopPrank();

        // Verify results
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(nftMinter.s_tokenCounter(), 2);
        assertEq(nftMinter.balanceOf(user1, tokenId1), 1);
        assertEq(nftMinter.balanceOf(user1, tokenId2), 1);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetDomainOwner() public {
        vm.prank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);

        assertEq(nftMinter.getDomainOwner(DOMAIN_1), user1);
    }

    function testIsDomainMintable() public {
        vm.prank(owner);
        nftMinter.setIsDomainMintable(DOMAIN_1, true);

        assertTrue(nftMinter.isDomainMintable(DOMAIN_1));
    }

    function testGetTokenIdForDomain() public {
        // Setup and mint
        vm.startPrank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);
        nftMinter.setIsDomainMintable(DOMAIN_1, true);
        vm.stopPrank();

        vm.prank(user1);
        uint256 tokenId = nftMinter.mintDomainNFT(DOMAIN_1);

        assertEq(nftMinter.getTokenIdForDomain(DOMAIN_1), tokenId);
    }

    function testGetTokenNameFromId() public {
        // Setup and mint
        vm.startPrank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);
        nftMinter.setIsDomainMintable(DOMAIN_1, true);
        vm.stopPrank();

        vm.prank(user1);
        uint256 tokenId = nftMinter.mintDomainNFT(DOMAIN_1);

        assertEq(nftMinter.getTokenNameFromId(tokenId), DOMAIN_1);
    }

    function testUriGeneration() public {
        // Setup and mint
        vm.startPrank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, user1);
        nftMinter.setIsDomainMintable(DOMAIN_1, true);
        vm.stopPrank();

        vm.prank(user1);
        uint256 tokenId = nftMinter.mintDomainNFT(DOMAIN_1);

        string memory expectedUri = string(
            abi.encodePacked("ipfs://", Strings.toString(tokenId))
        );
        assertEq(nftMinter.uri(tokenId), expectedUri);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_DomainOwnership(address randomUser) public {
        // Skip zero address and contract address
        vm.assume(randomUser != address(0));
        vm.assume(randomUser != address(nftMinter));

        vm.prank(owner);
        nftMinter.setDomainNameToOwner(DOMAIN_1, randomUser);

        assertEq(nftMinter.getDomainOwner(DOMAIN_1), randomUser);
    }

    function testFuzz_MintMultipleDomainsForSameUser(
        string memory domainName1,
        string memory domainName2
    ) public {
        // Ensure domain names are different and valid
        vm.assume(
            bytes(domainName1).length > 0 && bytes(domainName1).length <= 32
        );
        vm.assume(
            bytes(domainName2).length > 0 && bytes(domainName2).length <= 32
        );
        vm.assume(
            keccak256(bytes(domainName1)) != keccak256(bytes(domainName2))
        );

        // Setup domains
        vm.startPrank(owner);
        nftMinter.setDomainNameToOwner(domainName1, user1);
        nftMinter.setIsDomainMintable(domainName1, true);
        nftMinter.setDomainNameToOwner(domainName2, user1);
        nftMinter.setIsDomainMintable(domainName2, true);
        vm.stopPrank();

        // Mint both domains
        vm.startPrank(user1);
        uint256 tokenId1 = nftMinter.mintDomainNFT(domainName1);
        uint256 tokenId2 = nftMinter.mintDomainNFT(domainName2);
        vm.stopPrank();

        // Verify results
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(nftMinter.s_tokenCounter(), 2);
        assertEq(nftMinter.getTokenNameFromId(tokenId1), domainName1);
        assertEq(nftMinter.getTokenNameFromId(tokenId2), domainName2);
    }
}
