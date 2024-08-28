module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          evmVersion: "cancun",
          viaIR: process.env.HARDHAT_VIA_IR === "true",
          optimizer: {
            enabled: true,
            runs: 9999999,
          },
        },
      },
      {
        version: "0.8.20",
        settings: {
          viaIR: process.env.HARDHAT_VIA_IR === "true",
          optimizer: {
            enabled: true,
            runs: 9999999,
          },
        },
      },
    ],
  },
  paths: {
    sources: process.env.HARDHAT_CONTRACTS_PATH || "contracts",
    artifacts: "artifacts",
    cache: "cache",
  },
};
