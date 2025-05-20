// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title StringBytes32
/// @notice Library for converting between string and bytes32
/// @dev Provides reversible conversion for strings up to 32 bytes long
library StringBytes32 {
    /// @notice Converts a string to bytes32 for storage (reversible)
    /// @dev Only works for strings up to 32 bytes in length
    /// @param str The string to convert
    /// @return result The bytes32 representation of the string
    function stringToBytes32(string memory str) public pure returns (bytes32 result) {
        // We need to check if the string is too long
        bytes memory strBytes = bytes(str);
        require(strBytes.length <= 32, "String too long for bytes32");
        
        // Convert to bytes32
        assembly {
            result := mload(add(str, 32))
        }
        return result;
    }

    /// @notice Converts a bytes32 back to its original string
    /// @dev Pair this with stringToBytes32 for reversible conversion
    /// @param data The bytes32 value to convert
    /// @return The original string
    function bytes32ToString(bytes32 data) public pure returns (string memory) {
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
}
