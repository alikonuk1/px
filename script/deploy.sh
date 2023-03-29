source .env

#ETHERSCAN = $ETHERSCAN_API_KEY
#POLYGONSCAN = $PSCAN_API_KEY
#--gas-estimate-multiplier 90
#2222 https://rpc.kava.io 

forge script script/Deploy.s.sol:Deploy --chain-id 1 --rpc-url https://rpc.ankr.com/eth \
    --broadcast --etherscan-api-key $ETHERSCAN_API_KEY \
    --verify -vvvv 