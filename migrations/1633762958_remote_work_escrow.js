const RemoteWorkEscrow = artifacts.require("RemoteWorkEscrow");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(RemoteWorkEscrow, accounts[1]);
};
