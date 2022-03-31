// Defining bytecode and abi from original contract on mainnet to ensure bytecode matches and it produces the same pair code hash
const {
  bytecode,
  abi,
  metadata
} = require("../deployments/bsc/UniswapV2Factory.json");

module.exports = async function ({
  ethers,
  getNamedAccounts,
  deployments,
  getChainId,
}) {
  const { deploy, execute } = deployments;

  const { deployer, dev } = await getNamedAccounts();

  await deploy("UniswapV2Factory", {
    contract: {
      abi,
      bytecode,
      metadata
    },
    from: dev,
    args: [dev],
    log: true,
    deterministicDeployment: false,
  });


  const UniswapV2Factory = await ethers.getContract("UniswapV2Factory")
  if (await UniswapV2Factory.feeTo() !== dev) {
    console.log("Setting fee to dev")
    await execute(
      'UniswapV2Factory',
      {from: dev, log: true},
      'setFeeTo',
      dev
    );
  }

};

module.exports.tags = ["UniswapV2Factory", "AMM"];
