// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/MiniNFTPro.sol";

contract LocalAnvilCheckScript is Script {
    function run() external {
        uint256 ownerPk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(ownerPk);
        address receiver = vm.envAddress("RECEIVER_ADDR");

        string memory name_ = vm.envOr("TOKEN_NAME", string("Mini NFT Pro"));
        string memory symbol_ = vm.envOr("TOKEN_SYMBOL", string("MNFTP"));
        string memory baseURI_ = vm.envOr("BASE_URI", string("https://meta.local/token/"));

        vm.startBroadcast(ownerPk);

        MiniNFTPro nft = new MiniNFTPro(name_, symbol_, baseURI_);
        nft.mint(owner, 1);
        require(nft.ownerOf(1) == owner, "mint assertion failed");

        nft.transferFrom(owner, receiver, 1);
        require(nft.ownerOf(1) == receiver, "transfer assertion failed");

        vm.stopBroadcast();

        console2.log("Contract:", address(nft));
        console2.log("Owner:", owner);
        console2.log("Receiver:", receiver);
        console2.log("ownerOf(1):", nft.ownerOf(1));
        console2.log("tokenURI(1):", nft.tokenURI(1));
        console2.log("Local anvil test flow completed.");
    }
}
