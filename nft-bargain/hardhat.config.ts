import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
    solidity: "0.8.9",
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {},
        ganacha: {
            url: 'http://127.0.0.1:7545',
            accounts: [
                // test accounts, shoule be changed
                'cd2cb4e5434133ea71a28f68d9bb02584bb9caa09c21220bf1778cf2b90c7eea',
                '7bfae2a6bd0fae02ba5b0abe46ca089cacb3cfb832779fd542113e479d7657e9',
                '3da32b8c495cd9622cb89dbf065a8557c3c845c1782be2be0546156363eaf1e2',
                '1bb031bdccf6d1b8ca86118ea9124cb3f2d7fa663d828a2f6c1b64b635d2116a',
            ]
        }
    }
};

export default config;
