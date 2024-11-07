pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHedgeUnit} from "../../interfaces/IHedgeUnit.sol";
import {ICommon} from "../../interfaces/ICommon.sol";
import {Id} from "../../libraries/Pair.sol";
import {Asset} from "./Asset.sol";

struct DSData {
    address dsAddress;
    uint256 totalDeposited;
}

/**
 * @title HedgeUnit
 * @notice This contract allows minting and dissolving HedgeUnit tokens in exchange for two underlying assets.
 * @dev The contract uses OpenZeppelin's ERC20, ReentrancyGuard,Pausable and Ownable modules.
 */
contract HedgeUnit is ERC20, ReentrancyGuard, Ownable, Pausable, IHedgeUnit {
    using SafeERC20 for IERC20;

    ICommon public immutable MODULE_CORE;
    Id public immutable ID;

    /// @notice The ERC20 token representing the PA asset.
    IERC20 public immutable PA;
    uint8 public immutable paDecimals;

    /// @notice The ERC20 token representing the ds asset.
    Asset public ds;

    /// @notice Maximum supply cap for minting HedgeUnit tokens.
    uint256 public mintCap;

    DSData[] public dsHistory;
    mapping(address => uint256) private dsIndexMap;

    error NoValidDSExist();

    /**
     * @dev Constructor that sets the DS and PA tokens and initializes the mint cap.
     * @param _moduleCore Address of the MODULE_CORE.
     * @param _PA Address of the PA token.
     * @param _pairName Name of the HedgeUnit pair.
     * @param _mintCap Initial mint cap for the HedgeUnit tokens.
     */
    constructor(address _moduleCore, Id _id, address _PA, string memory _pairName, uint256 _mintCap)
        ERC20(string(abi.encodePacked("Hedge Unit - ", _pairName)), string(abi.encodePacked("HU - ", _pairName)))
        Ownable(msg.sender)
    {
        MODULE_CORE = ICommon(_moduleCore);
        ID = _id;
        PA = IERC20(_PA);
        paDecimals = uint8(ERC20(_PA).decimals());
        mintCap = _mintCap;
    }

    /**
     * @dev Internal function to get the latest DS address.
     * Calls MODULE_CORE to get the latest DS id and retrieves the associated DS address.
     */
    function _getLastDS() internal {
        if (address(ds) == address(0) || ds.isExpired()) {
            uint256 dsId = MODULE_CORE.lastDsId(ID);
            (, address dsAdd) = MODULE_CORE.swapAsset(ID, dsId);

            if (dsAdd == address(0) || Asset(dsAdd).isExpired()) {
                revert NoValidDSExist();
            }

            // Check if the DS address already exists in history
            bool found = false;
            uint256 index = dsIndexMap[dsAdd];
            if (dsHistory.length > 0 && dsHistory[index].dsAddress == dsAdd) {
                // DS address is already at index
                ds = Asset(dsAdd);
                found = true;
            }

            // If not found, add new DS address to history
            if (!found) {
                ds = Asset(dsAdd);
                dsHistory.push(DSData({dsAddress: dsAdd, totalDeposited: 0}));
                dsIndexMap[dsAdd] = dsHistory.length - 1; // Store the index
            }
        }
    }

    /**
     * @notice Mints HedgeUnit tokens by transferring the equivalent amount of DS and PA tokens.
     * @dev The function checks for the paused state and mint cap before minting.
     * @param amount The amount of HedgeUnit tokens to mint.
     * @custom:reverts EnforcedPause if minting is currently paused.
     * @custom:reverts MintCapExceeded if the mint cap is exceeded.
     */
    function mint(uint256 amount) external whenNotPaused nonReentrant {
        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }
        _getLastDS();

        IERC20(ds).safeTransferFrom(msg.sender, address(this), amount);
        uint256 paAmount = (amount * (10 ** paDecimals)) / (10 ** 18);
        PA.safeTransferFrom(msg.sender, address(this), paAmount);
        dsHistory[dsIndexMap[address(ds)]].totalDeposited += amount;

        _mint(msg.sender, amount);

        emit Mint(msg.sender, amount);
    }

    /**
     * @notice Dissolves HedgeUnit tokens and returns the equivalent amount of DS and PA tokens.
     * @param amount The amount of HedgeUnit tokens to dissolve.
     * @return dsAmount The amount of DS tokens returned.
     * @return paAmount The amount of PA tokens returned.
     * @custom:reverts EnforcedPause if minting is currently paused.
     * @custom:reverts InvalidAmount if the user has insufficient HedgeUnit balance.
     */
    function dissolve(uint256 amount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 dsAmount, uint256 paAmount)
    {
        if (amount > balanceOf(msg.sender)) {
            revert InvalidAmount();
        }

        uint256 totalSupplyHU = totalSupply();

        dsAmount = (amount * ds.balanceOf(address(this))) / totalSupplyHU;
        paAmount = (amount * PA.balanceOf(address(this))) / (totalSupplyHU * (10 ** (18 - paDecimals)));

        _burn(msg.sender, amount);
        IERC20(ds).safeTransfer(msg.sender, dsAmount);
        PA.safeTransfer(msg.sender, paAmount);

        emit Dissolve(msg.sender, amount, dsAmount, paAmount);
    }

    /**
     * @notice Updates the mint cap.
     * @param _newMintCap The new mint cap value.
     * @custom:reverts InvalidValue if the mint cap is not changed.
     */
    function updateMintCap(uint256 _newMintCap) external onlyOwner {
        if (_newMintCap == mintCap) {
            revert InvalidValue();
        }
        mintCap = _newMintCap;
        emit MintCapUpdated(_newMintCap);
    }

    /**
     * @notice Pause this contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause this contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
