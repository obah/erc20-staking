import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TokenMModule = buildModule("TokenMModule", (m) => {
  const tokenM = m.contract("TokenM", []);

  return { tokenM };
});

export default TokenMModule;
