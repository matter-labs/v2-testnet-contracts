module.exports = {
    solidity: {
      version: "0.8.16",
      settings: {
        optimizer: {
          enabled: true,
          runs: 1000,
        }
      }
    },
    paths: {
      sources: "./l1",
      cache: "./cache",
      artifacts: "./artifacts"
    },
    mocha: {
      timeout: 40000
    }
}
  