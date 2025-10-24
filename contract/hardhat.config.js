require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // Focus only on Oracle contracts and exclude v3-core and other problematic contracts
  paths: {
    sources: "./contracts",
  },
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    "hedera-testnet": {
      url: `https://testnet.hashio.io/api`,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};
