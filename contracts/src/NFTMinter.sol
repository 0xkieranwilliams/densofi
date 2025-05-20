// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "src/libraries/StringBytes32.sol";

/**
 * @title NFTMinter
 * @dev A contract for minting NFTs that represent domain ownership
 * Works with a multi-chain domain registration system
 */
contract NFTMinter is ERC1155, Ownable {
    using Strings for uint256;
    using StringBytes32 for string;
    using StringBytes32 for bytes32;
    
    // Counter for token IDs
    uint256 public s_tokenCounter;
    
    // Mappings for domain tracking
    mapping(bytes32 => uint256) public s_domainNameToTokenId;
    mapping(uint256 => bytes32) public s_tokenIdToDomainName;
    mapping(bytes32 => bool) public s_isDomainMintable;
    mapping(bytes32 => address) public s_domainNameToOwner;
    mapping(bytes32 => bool) public s_isDomainNFTMinted;
    
    // Events
    event NFTMinted(uint256 indexed tokenId, address indexed to, bytes32 domainNameHash, string domainName);
    event DomainOwnerSet(bytes32 indexed domainNameHash, address owner, string domainName);
    event DomainMintableStatusSet(bytes32 indexed domainNameHash, bool isMintable, string domainName);
    event DomainNFTMintedStatusSet(bytes32 indexed domainNameHash, bool isMinted, string domainName);
    
    /**
     * @dev Constructor sets the IPFS base URI and initializes ownership
     */
    constructor() ERC1155("ipfs://") Ownable(msg.sender) {
        s_tokenCounter = 0;
    }
    
    /// @notice Converts a string to bytes32 for storage (reversible)
    /// @dev Only works for strings up to 32 bytes in length
    /// @param str The string to convert
    /// @return result The bytes32 representation of the string
    function _stringToBytes32(string memory str) internal pure returns (bytes32 result) {
        // We need to check if the string is too long
        bytes memory strBytes = bytes(str);
        require(strBytes.length <= 32, "String too long for bytes32");
        
        // Convert to bytes32
        assembly {
            result := mload(add(str, 32))
        }
        return result;
    }

    /**
     * @dev Mints a new NFT representing a domain name
     * @param domainName The domain name to mint an NFT for
     * @return tokenId The ID of the newly minted token
     */
    function mintDomainNFT(string memory domainName) public returns (uint256) {
        bytes32 domainNameHash = domainName.stringToBytes32();
        
        // Check if caller is the verified domain owner
        require(msg.sender == s_domainNameToOwner[domainNameHash], "Caller is not the domain owner");
        
        // Check if domain is available for minting
        require(s_isDomainMintable[domainNameHash] == true, "Domain not available for minting");
        
        // Check if domain NFT has not already been minted
        require(s_isDomainNFTMinted[domainNameHash] == false, "Domain NFT already minted");
        
        // Increment token counter and mint NFT
        s_tokenCounter++;
        uint256 tokenId = s_tokenCounter;
        
        // Set mappings
        s_domainNameToTokenId[domainNameHash] = tokenId;
        s_tokenIdToDomainName[tokenId] = domainNameHash;
        s_isDomainNFTMinted[domainNameHash] = true;
        
        // Mint the token
        _mint(msg.sender, tokenId, 1, "");
        
        // Emit event
        emit NFTMinted(tokenId, msg.sender, domainNameHash, domainName);
        
        return tokenId;
    }
    
    /**
     * @dev Sets the owner of a domain name (admin only)
     * @param domainName The domain name
     * @param domainOwner The address of the domain owner
     */
    function setDomainNameToOwner(string memory domainName, address domainOwner) 
        public 
        onlyOwner 
    {
        bytes32 domainNameHash = domainName.stringToBytes32();
        s_domainNameToOwner[domainNameHash] = domainOwner;
        emit DomainOwnerSet(domainNameHash, domainOwner, domainName);
    }
    
    /**
     * @dev Sets whether a domain is available for NFT minting (admin only)
     * @param domainName The domain name
     * @param availableForNFTMinting Whether the domain is available for minting
     */
    function setIsDomainMintable(string memory domainName, bool availableForNFTMinting) 
        public 
        onlyOwner 
    {
        bytes32 domainNameHash = domainName.stringToBytes32();
        s_isDomainMintable[domainNameHash] = availableForNFTMinting;
        emit DomainMintableStatusSet(domainNameHash, availableForNFTMinting, domainName);
    }
    
    /**
     * @dev Manually sets whether a domain NFT has been minted (admin only)
     * Useful for cross-chain synchronization if events are missed
     * @param domainName The domain name
     * @param isMinted Whether the domain NFT has been minted
     */
    function setIsDomainNFTMinted(string memory domainName, bool isMinted) 
        public 
        onlyOwner 
    {
        bytes32 domainNameHash = domainName.stringToBytes32();
        s_isDomainNFTMinted[domainNameHash] = isMinted;
        emit DomainNFTMintedStatusSet(domainNameHash, isMinted, domainName);
    }

    /**
     * @dev Returns the URI for a given token ID
     * @param tokenId The ID of the token
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        // Concatenate the base URI with the token ID
        // In a production environment, this should point to a proper IPFS metadata file
        return string(abi.encodePacked(super.uri(tokenId), tokenId.toString()));
    }
    
    /**
     * @dev Returns the domain name associated with a token ID
     * @param tokenId The ID of the token
     * @return The domain name as a string
     */
    function getTokenNameFromId(uint256 tokenId) public view returns (string memory) {
        bytes32 domainName = s_tokenIdToDomainName[tokenId];
        return domainName.bytes32ToString();
    }
    
    /**
     * @dev Returns the owner of a domain
     * @param domainName The domain name
     * @return The address of the domain owner
     */
    function getDomainOwner(string memory domainName) public view returns (address) {
        bytes32 domainNameHash = domainName.stringToBytes32();
        return s_domainNameToOwner[domainNameHash];
    }
    
    
    /**
     * @dev Returns whether a domain is available for minting
     * @param domainName The domain name
     */
    function isDomainMintable(string memory domainName) public view returns (bool) {
        bytes32 domainNameHash = domainName.stringToBytes32();
        return s_isDomainMintable[domainNameHash];
    }
    
    /**
     * @dev Returns the token ID for a domain name
     * @param domainName The domain name
     */
    function getTokenIdForDomain(string memory domainName) public view returns (uint256) {
        bytes32 domainNameHash = domainName.stringToBytes32();
        return s_domainNameToTokenId[domainNameHash];
    }
    
    /**
     * @dev Override of supportsInterface function
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
