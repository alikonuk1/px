source .env

#ETHERSCAN = $ETHERSCAN_API_KEY
#POLYGONSCAN = $PSCAN_API_KEY

forge script script/Deploy.s.sol:Deploy --chain-id 5 --rpc-url https://rpc.ankr.com/eth_sepolia \
    --broadcast --etherscan-api-key $ETHERSCAN_API_KEY \
    --verify -vvvv 