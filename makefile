include .env
export

deploy:
	@forge script script/DeployMissCosmoVoting.s.sol:DeployMissCosmoVoting --rpc-url $SEPOLIA_RPC_URL --account $ACCOUNT --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
