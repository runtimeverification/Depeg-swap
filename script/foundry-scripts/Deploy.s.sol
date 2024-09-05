pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {IUniswapV2Factory} from "uniswap-v2/contracts/interfaces/IUniswapV2Factory.sol";

string constant v2FactoryArtifact = "test/helper/ext-abi/uni-v2-factory.json";
string constant v2RouterArtifact = "test/helper/ext-abi/uni-v2-router.json";

contract DeployScript is Script {
    IUniswapV2Factory public factory;
    IUniswapV2Router public univ2Router;

    AssetFactory public assetFactory;
    CorkConfig public config;
    RouterState public flashswapRouter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address moduleCore = address(0x1234567890123456789012345678901234567890);
        address univ2Router = address(0x1234567890123456789012345678901234567890);

        // Deploy the Asset Factory implementation (logic) contract
        AssetFactory assetFactoryImplementation = new AssetFactory();
        console.log("Asset Factory Implementation    : ", address(assetFactoryImplementation));

        // Deploy the Asset Factory Proxy contract
        bytes memory data = abi.encodeWithSelector(assetFactoryImplementation.initialize.selector);
        ERC1967Proxy assetFactoryProxy = new ERC1967Proxy(address(assetFactoryImplementation), data);
        assetFactory = AssetFactory(address(assetFactoryProxy));
        console.log("Asset Factory                   : ", address(assetFactory));

        // Deploy the CorkConfig contract
        config = new CorkConfig();
        console.log("Cork Config                     : ", address(config));

        // Deploy the FlashSwapRouter implementation (logic) contract
        RouterState routerImplementation = new RouterState();
        console.log("Flashswap Router Implementation : ", address(routerImplementation));

        // Deploy the FlashSwapRouter Proxy contract
        data = abi.encodeWithSelector(routerImplementation.initialize.selector);
        ERC1967Proxy routerProxy = new ERC1967Proxy(address(routerImplementation), data);
        flashswapRouter = RouterState(address(routerProxy));
        console.log("Flashswap Router Proxy          : ", address(flashswapRouter));

        // Transfer Ownership to moduleCore
        assetFactory.transferOwnership(moduleCore);
        flashswapRouter.transferOwnership(moduleCore);
        console.log("Transferred ownerships to Modulecore");

        // Deploy the UniswapV2Factory contract
        address _factory = deployCode(v2FactoryArtifact, abi.encode(msg.sender, address(flashswapRouter)));
        factory = IUniswapV2Factory(_factory);

        // Deploy the UniswapV2Router contract
        address _router = deployCode(v2FactoryArtifact, abi.encode(msg.sender, address(flashswapRouter)));
        univ2Router = IUniswapV2Factory(_router);
        vm.stopBroadcast();
    }
}
