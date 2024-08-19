module.exports = {
  solidity: {
    version: "0.8.24",
    evmVersion: "cancun",
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999999,
      },
    },
  },
  paths: {
    sources: "contracts",
    artifacts: "artifacts",
    cache: "cache",
  },
};
