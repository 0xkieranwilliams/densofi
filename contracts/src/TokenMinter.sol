// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./NFTMinter.sol";
import {InitialSupplySuperchainERC20} from "./InitialSupplySuperchainERC20.sol";

/**
 * @title TokenMinter
 * @dev Contract that allows creating ERC20 tokens from NFTs
 * 
 * This contract allows users with the MINTER_ROLE to create ERC20 tokens
 * based on NFTs they own. The NFT is transferred to this contract and
 * becomes the backing for the new ERC20 token.
 */
contract TokenMinter is IERC1155Receiver {
    
    // Reference to the NFT contract
    NFTMinter public nftContract;
    
    // Mapping to track which NFTs have been used to mint tokens
    mapping(uint256 => bool) public usedNFTs;
    
    // Mapping to store created token contracts
    mapping(uint256 => address) public nftToToken;
    
    // Mapping to store NFT names
    mapping(uint256 => string) private _nftNames;
    
    event TokenCreated(uint256 indexed nftId, address tokenAddress, string tokenName);
    event NFTReceived(uint256 indexed tokenId, address from);
    
    /**
     * @dev Constructor initializes the contract with the NFT contract address
     * @param _nftContract Address of the NFTMinter contract
     */
    constructor(address _nftContract) {
        nftContract = NFTMinter(_nftContract);
    }

    /// @notice Converts a bytes32 back to its original string
    /// @param data The bytes32 value to convert
    /// @return The original string
    function _bytes32ToString(bytes32 data) internal pure returns (string memory) {
        // First convert to bytes
        bytes memory bytesData = new bytes(32);
        
        // Copy bytes32 to bytes array
        assembly {
            mstore(add(bytesData, 32), data)
        }
        
        // Find string length (first occurrence of 0)
        uint length;
        for (length = 0; length < 32; length++) {
            if (bytesData[length] == 0) {
                break;
            }
        }
        
        // Create a properly sized result
        bytes memory result = new bytes(length);
        for (uint i = 0; i < length; i++) {
            result[i] = bytesData[i];
        }
        
        return string(result);
    }
    
    /**
     * @dev Creates a new Superchain ERC20 token based on an NFT
     * @param nftId The ID of the NFT to use as reference
     * @return tokenAddress The address of the created token contract
     * 
     * Requirements:
     * - NFT must not have been used to create a token before
     * - Caller must own the NFT
     */
    function createTokenFromNFT(uint256 nftId) public returns (address tokenAddress) {
        require(!usedNFTs[nftId], "NFT already used to create a token");
        
        // Check if the caller owns the NFT
        require(nftContract.balanceOf(msg.sender, nftId) > 0, "ERC1155: caller is not token owner");
        
        string memory nftName = _bytes32ToString(nftContract.s_tokenIdToDomainName(nftId));
        string memory tokenName = string(abi.encodePacked(nftName, " Token"));
        string memory tokenSymbol = string(abi.encodePacked(nftName, "T"));
        
        // Store the NFT name before transfer
        _nftNames[nftId] = nftName;
        
        // Transfer the NFT to this contract and emit event
        nftContract.safeTransferFrom(msg.sender, address(this), nftId, 1, "");
        emit NFTReceived(nftId, msg.sender);
        
        // Create new Superchain ERC20 token with 1 million initial supply
        InitialSupplySuperchainERC20 newToken = new InitialSupplySuperchainERC20(
            msg.sender,  // owner
            tokenName,   // name
            tokenSymbol, // symbol
            18,         // decimals
            1_000_000 * 10**18, // initial supply (1 million tokens with 18 decimals)
            block.chainid // initial supply chain ID (current chain)
        );
        
        tokenAddress = address(newToken);
        
        // Mark NFT as used
        usedNFTs[nftId] = true;
        
        // Store the token contract address
        nftToToken[nftId] = tokenAddress;
        
        emit TokenCreated(nftId, tokenAddress, tokenName);
        
        return tokenAddress;
    }
    
    /**
     * @dev Returns the token contract address for a given NFT ID
     * @param nftId The ID of the token
     * @return The address of the token contract created from this NFT
     */
    function getTokenAddress(uint256 nftId) public view returns (address) {
        return nftToToken[nftId];
    }
    
    /**
     * @dev Returns the name of the NFT used to create a token
     * @param nftId The ID of the NFT
     * @return The name of the NFT
     */
    function getNFTName(uint256 nftId) public view returns (string memory) {
        return _nftNames[nftId];
    }
    
    /**
     * @dev Required by IERC1155Receiver
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }
    
    /**
     * @dev Required by IERC1155Receiver
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
    
    /**
     * @dev Required by IERC1155Receiver
     */
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        override
        returns (bool)
    {
        return interfaceId == type(IERC1155Receiver).interfaceId ||
               interfaceId == type(IERC165).interfaceId;
    }
} 
