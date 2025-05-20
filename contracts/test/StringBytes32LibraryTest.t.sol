// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/libraries/StringBytes32.sol";

contract StringBytes32LibraryTest is Test {
    // Use the library for our test contract
    using StringBytes32 for string;
    using StringBytes32 for bytes32;
    
    // Event to log the string and its bytes32 representation
    event StringConverted(string original, bytes32 converted);
    
    // Event to log the bytes32 and its string representation
    event Bytes32Converted(bytes32 original, string converted);
    
    function setUp() public {
        // Setup code if needed
    }

    function testStringToBytes32Conversion() public {
        // Test case 1: Short domain name
        string memory testString1 = "example.eth";
        bytes memory strBytes1 = bytes(testString1);
        console.log("Length of testString1:", strBytes1.length, "bytes");
        testStringConversion(testString1);
        
        // Test case 2: Medium length domain (but still under 32 bytes)
        string memory testString2 = "medium-example.eth";
        bytes memory strBytes2 = bytes(testString2);
        console.log("Length of testString2:", strBytes2.length, "bytes");
        testStringConversion(testString2);
        
        // Test case 3: Domain with special characters
        string memory testString3 = "special-chars_123.eth";
        bytes memory strBytes3 = bytes(testString3);
        console.log("Length of testString3:", strBytes3.length, "bytes");
        testStringConversion(testString3);
        
        // Test case 4: Domain approaching the limit (30 bytes)
        string memory testString4 = "approaching-limit-domain.eth";
        bytes memory strBytes4 = bytes(testString4);
        console.log("Length of testString4:", strBytes4.length, "bytes");
        testStringConversion(testString4);
    }
    
    function testStringConversion(string memory original) internal {
        // Convert string to bytes32 using the library
        bytes32 converted = original.stringToBytes32();
        
        // Log the conversion
        emit StringConverted(original, converted);
        
        // Convert back to string using the library
        string memory roundTrip = converted.bytes32ToString();
        
        // Log the conversion back
        emit Bytes32Converted(converted, roundTrip);
        
        // Assert that the round trip conversion matches the original
        assertEq(
            keccak256(abi.encodePacked(original)),
            keccak256(abi.encodePacked(roundTrip)),
            "String conversion round trip failed"
        );
        
        // Output to console for better readability in test logs
        console.log("Original string:", original);
        console.logBytes32(converted);
        console.log("Converted back:", roundTrip);
        console.log("----------------------------");
    }
    
    function testTooLongString() public {
        // This string is more than 32 bytes and should fail
        string memory tooLong = "this-string-is-definitely-too-long-to-fit-in-bytes32-storage.eth";
        bytes memory tooLongBytes = bytes(tooLong);
        console.log("Length of too long string:", tooLongBytes.length, "bytes");
        
        // This should revert with "String too long for bytes32"
        vm.expectRevert("String too long for bytes32");
        tooLong.stringToBytes32();
    }

    // Additional test - using the library functions directly without using directives
    function testLibraryDirectCall() public pure {
        string memory testString = "direct-call-test.eth";
        
        // Direct call to library function
        bytes32 converted = StringBytes32.stringToBytes32(testString);
        string memory roundTrip = StringBytes32.bytes32ToString(converted);
        
        console.log("Direct call - Original:", testString);
        console.logBytes32(converted);
        console.log("Direct call - Converted back:", roundTrip);
        
        // Verify result
        assertEq(
            keccak256(abi.encodePacked(testString)),
            keccak256(abi.encodePacked(roundTrip)),
            "Direct library call conversion failed"
        );
    }
}
