-include .env

.PHONY: help deploy-sepolia verify-sepolia test clean get-address

help:
	@echo "Available commands:"
	@echo "  make deploy-sepolia   - Deploy contracts to Sepolia testnet"
	@echo "  make verify-sepolia   - Verify contracts on Sepolia after deployment"
	@echo "  make test            - Run forge tests"
	@echo "  make get-address     - Get your wallet address from private key"
	@echo "  make clean           - Clean build artifacts"

# Check if required environment variables are set
check-env:
	@if [ -z "$(PRIVATE_KEY)" ]; then \
		echo "Error: PRIVATE_KEY is not set. Add it to .env file or export it."; \
		exit 1; \
	fi
	@if [ -z "$(INFURA_API_KEY)" ]; then \
		echo "Error: INFURA_API_KEY is not set. Add it to .env file or export it."; \
		exit 1; \
	fi

# Deploy to Sepolia (without verification)
deploy-sepolia: check-env
	@echo "Deploying to Sepolia..."
	@mkdir -p deployment-addresses
	@DEPLOYER_ADDRESS=$$(cast wallet address --private-key $(PRIVATE_KEY)); \
	OUTPUT=$$(forge script script/DeployContracts.s.sol --rpc-url https://sepolia.infura.io/v3/$(INFURA_API_KEY) --sender $$DEPLOYER_ADDRESS --broadcast -vvvv); \
	echo "$$OUTPUT" | grep "deployed at:" | awk '{ \
		if ($$1 == "DomainRegistration") addr1=$$4; \
		if ($$1 == "NFTMinter") addr2=$$4; \
		if ($$1 == "TokenMinter") addr3=$$4; \
	} END { \
		print "{"; \
		print "  \"DomainRegistration\": \"" addr1 "\","; \
		print "  \"NFTMinter\": \"" addr2 "\","; \
		print "  \"TokenMinter\": \"" addr3 "\""; \
		print "}"; \
	}' > deployment-addresses/sepolia-addresses.json

	@echo "Deployment complete. Addresses saved to deployment-addresses/sepolia-addresses.json"

# Verify contracts on Sepolia
verify-sepolia: check-env
	@if [ -z "$(ETHERSCAN_API_KEY)" ]; then \
		echo "Error: ETHERSCAN_API_KEY is not set for verification"; \
		exit 1; \
	fi
	@echo "Cleaning and rebuilding contracts..."
	@forge clean
	@forge build --force
	@echo "Verifying contracts on Sepolia..."
	
	@DEPLOYER_ADDRESS=$$(cast wallet address --private-key $(PRIVATE_KEY)); \
	DOMAIN_REGISTRATION_ADDRESS=$$(cat deployment-addresses/sepolia-addresses.json | jq -r '.DomainRegistration'); \
	NFT_MINTER_ADDRESS=$$(cat deployment-addresses/sepolia-addresses.json | jq -r '.NFTMinter'); \
	TOKEN_MINTER_ADDRESS=$$(cat deployment-addresses/sepolia-addresses.json | jq -r '.TokenMinter'); \
	echo "Verifying DomainRegistration at $$DOMAIN_REGISTRATION_ADDRESS..."; \
	forge verify-contract \
		--chain-id 11155111 \
		--num-of-optimizations 200 \
		--watch \
		--constructor-args $$(cast abi-encode "constructor(uint256,address)" 10000000000000000 $$DEPLOYER_ADDRESS) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--compiler-version v0.8.30 \
		$$DOMAIN_REGISTRATION_ADDRESS \
		DomainRegistration; \
	echo "Verifying NFTMinter at $$NFT_MINTER_ADDRESS..."; \
	forge verify-contract \
		--chain-id 11155111 \
		--num-of-optimizations 200 \
		--watch \
		--constructor-args $$(cast abi-encode "constructor(address)" $$DEPLOYER_ADDRESS) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--compiler-version v0.8.30 \
		$$NFT_MINTER_ADDRESS \
		NFTMinter; \
	echo "Verifying TokenMinter at $$TOKEN_MINTER_ADDRESS..."; \
	forge verify-contract \
		--chain-id 11155111 \
		--num-of-optimizations 200 \
		--watch \
		--constructor-args $$(cast abi-encode "constructor(address,address)" $$DEPLOYER_ADDRESS $$NFT_MINTER_ADDRESS) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--compiler-version v0.8.30 \
		$$TOKEN_MINTER_ADDRESS \
		TokenMinter

# Run tests
test:
	@echo "Running tests..."
	@forge test -vv

get-address: check-env
	@echo "Your public address is:"
	@cast wallet address --private-key $(PRIVATE_KEY)

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@forge clean