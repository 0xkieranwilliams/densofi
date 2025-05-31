// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ICreateX} from "@createx/ICreateX.sol";

import {DomainRegistration} from "../src/DomainRegistration.sol";
import {NFTMinter} from "../src/NFTMinter.sol";
import {TokenMinter} from "../src/TokenMinter.sol";

/**
 * @title DeployContracts
 * @notice This script deploys all contracts across multiple chains using deterministic addresses
 * @dev Uses the CreateX contract for deterministic cross-chain deployment
 */
contract DeployContracts is Script {
    // Deployment addresses
    address public domainRegistrationAddress;
    address public nftMinterAddress;
    address public tokenMinterAddress;

    // Salt for deterministic deployments
    bytes32 private salt;

    // Deployment parameters
    uint256 private constant INITIAL_DOMAIN_REGISTRATION_FEE = 0.01 ether;

    // CreateX instance
    ICreateX private createX;

    // Deployer address (will be set as owner)
    address private deployer;

    function setUp() public {
        salt = bytes32(uint256(0x694206942069420));
    }

    function run() public {
        uint256 privateKeyInt = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKeyInt);

        // Set deployer address
        deployer = vm.addr(privateKeyInt);
        console2.log("Deploying with address:", deployer);

        // Check if CreateX is already deployed
        address createXAddress = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
        if (!_isContract(createXAddress)) {
            revert("CreateX contract not deployed at expected address");
        }

        createX = ICreateX(createXAddress);
        console2.log("Using CreateX at:", createXAddress);

        // Deploy contracts with deterministic addresses
        deployContracts();

        console2.log("\nDeployments complete!");
        console2.log(
            "DomainRegistration deployed at:",
            domainRegistrationAddress
        );
        console2.log("NFTMinter deployed at:", nftMinterAddress);
        console2.log("TokenMinter deployed at:", tokenMinterAddress);

        vm.stopBroadcast();
    }

    function deployContracts() internal {
        // 1. Deploy DomainRegistration with deployer as owner
        bytes memory domainRegistrationInitCode = abi.encodePacked(
            type(DomainRegistration).creationCode,
            abi.encode(INITIAL_DOMAIN_REGISTRATION_FEE, deployer)
        );

        domainRegistrationAddress = createX.deployCreate2(
            salt,
            domainRegistrationInitCode
        );
        console2.log("\nDeploying DomainRegistration...");
        console2.log(
            "DomainRegistration deployed at:",
            domainRegistrationAddress
        );

        // 2. Deploy NFTMinter with deployer as owner
        bytes memory nftMinterInitCode = abi.encodePacked(
            type(NFTMinter).creationCode,
            abi.encode(deployer)
        );

        bytes32 nftMinterSalt = bytes32(uint256(salt) + 1);
        nftMinterAddress = createX.deployCreate2(
            nftMinterSalt,
            nftMinterInitCode
        );
        console2.log("\nDeploying NFTMinter...");
        console2.log("NFTMinter deployed at:", nftMinterAddress);

        // 3. Deploy TokenMinter with deployer as owner and NFTMinter address
        bytes memory tokenMinterInitCode = abi.encodePacked(
            type(TokenMinter).creationCode,
            abi.encode(deployer, nftMinterAddress)
        );

        bytes32 tokenMinterSalt = bytes32(uint256(salt) + 2);
        tokenMinterAddress = createX.deployCreate2(
            tokenMinterSalt,
            tokenMinterInitCode
        );
        console2.log("\nDeploying TokenMinter...");
        console2.log("TokenMinter deployed at:", tokenMinterAddress);
    }

    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
