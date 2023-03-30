const ethers = require('ethers');

const contractABI = [
    // ...
    {
        "inputs": [
            { "internalType": "address", "name": "trader", "type": "address" }
        ],
        "name": "isSolvent",
        "outputs": [
            { "internalType": "bool", "name": "", "type": "bool" },
            { "internalType": "uint256", "name": "", "type": "uint256" }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            { "internalType": "address", "name": "trader", "type": "address" }
        ],
        "name": "liquidate",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
    // ...
];

// Replace with your provider
const contractAddress = 'YOUR_CONTRACT_ADDRESS';
const provider = new ethers.providers.JsonRpcProvider('YOUR_PROVIDER_URL');
const contract = new ethers.Contract(contractAddress, contractABI, provider);

// Replace with your private key
const privateKey = 'YOUR_PRIVATE_KEY';
const wallet = new ethers.Wallet(privateKey, provider);

// Set the trader address you want to monitor
const traderAddress = 'TRADER_ADDRESS';

async function checkAndLiquidate() {
    try {
        const [isSolventFlag, _] = await contract.isSolvent(traderAddress);
        if (isSolventFlag) {
            const contractWithSigner = contract.connect(wallet);
            const tx = await contractWithSigner.liquidate(traderAddress);
            const receipt = await tx.wait();
            console.log('Liquidation successful:', receipt);
        } else {
            console.log('Trader is not solvent, no liquidation needed');
        }
    } catch (error) {
        console.error('Error during checkAndLiquidate:', error);
    }
}

provider.on('block', async (blockNumber) => {
    console.log('New block detected:', blockNumber);
    await checkAndLiquidate();
});
