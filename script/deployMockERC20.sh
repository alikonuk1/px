source .env

forge script script/DeployMockERC20.s.sol:DeployMockERC20 --rpc-url $MUMBAI_RPC_URL \
    --broadcast --etherscan-api-key $PSCAN_API_KEY \
    --verify -vvvv --legacy