// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import "@/access/Pausable.sol";

import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyManager.sol";
import "../../access/interfaces/IPauserRegistry.sol";


contract StrategyBase is Initializable,IStrategyBase, Pausable {
    using SafeERC20 for IERC20;

    uint8 internal constant PAUSED_DEPOSITS = 0;
    uint8 internal constant PAUSED_WITHDRAWALS = 1;


    uint256 internal constant SHARES_OFFSET = 1e3;

    uint256 internal constant BALANCE_OFFSET = 1e3;

    IStrategyManager public immutable strategyManager;

    IERC20 public underlyingToken;

    uint256 public totalShares;

    modifier onlyStrategyManager() {
        require(msg.sender == address(strategyManager), "StrategyBase.onlyStrategyManager");
        _;
    }

    constructor(IStrategyManager _strategyManager) {
        strategyManager = _strategyManager;
        _disableInitializers();
    }

    function initialize(IERC20 _underlyingToken, IPauserRegistry _pauserRegistry) public virtual initializer {
        _initializeStrategyBase(_underlyingToken, _pauserRegistry);
    }

    function _initializeStrategyBase(
        IERC20 _underlyingToken,
        IPauserRegistry _pauserRegistry
    ) internal onlyInitializing {
        underlyingToken = _underlyingToken;
        _initializePauser(_pauserRegistry, UNPAUSE_ALL);
    }


    function deposit(
        IERC20 token,
        uint256 amount
    ) external virtual override onlyStrategyManager returns (uint256 newShares) {
        _beforeDeposit(token, amount);

        uint256 priorTotalShares = totalShares;

        uint256 virtualShareAmount = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;

        uint256 virtualPriorTokenBalance = virtualTokenBalance - amount;
        newShares = (amount * virtualShareAmount) / virtualPriorTokenBalance;

        require(newShares != 0, "StrategyBase.deposit: newShares cannot be zero");

        totalShares = (priorTotalShares + newShares);
        return newShares;
    }

    function withdraw(
        address recipient,
        IERC20 token,
        uint256 amountShares
    ) external virtual override onlyStrategyManager {
        _beforeWithdrawal(recipient, token, amountShares);

        uint256 priorTotalShares = totalShares;

        require(
            amountShares <= priorTotalShares,
            "StrategyBase.withdraw: amountShares must be less than or equal to totalShares"
        );

        uint256 virtualPriorTotalShares = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;

        uint256 amountToSend = (virtualTokenBalance * amountShares) / virtualPriorTotalShares;

        totalShares = priorTotalShares - amountShares;

        _afterWithdrawal(recipient, token, amountToSend);
    }

    function _beforeDeposit(IERC20 token, uint256 amount) internal virtual {
        require(token == underlyingToken, "StrategyBase.deposit: Can only deposit underlyingToken");
    }

    function _beforeWithdrawal(address recipient, IERC20 token, uint256 amountShares) internal virtual {
        require(token == underlyingToken, "StrategyBase.withdraw: Can only withdraw the strategy token");
    }

    function _afterWithdrawal(address recipient, IERC20 token, uint256 amountToSend) internal virtual {
        token.safeTransfer(recipient, amountToSend);
    }

    function explanation() external pure virtual override returns (string memory) {
        return "Base Strategy implementation to inherit from for more complex implementations";
    }

    function sharesToUnderlyingView(uint256 amountShares) public view virtual override returns (uint256) {
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;
        return (virtualTokenBalance * amountShares) / virtualTotalShares;
    }

    function sharesToUnderlying(uint256 amountShares) public view virtual override returns (uint256) {
        return sharesToUnderlyingView(amountShares);
    }

    function underlyingToSharesView(uint256 amountUnderlying) public view virtual returns (uint256) {
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;
        return (amountUnderlying * virtualTotalShares) / virtualTokenBalance;
    }

    function underlyingToShares(uint256 amountUnderlying) external view virtual returns (uint256) {
        return underlyingToSharesView(amountUnderlying);
    }

    function userUnderlyingView(address user) external view virtual returns (uint256) {
        return sharesToUnderlyingView(shares(user));
    }

    function userUnderlying(address user) external virtual returns (uint256) {
        return sharesToUnderlying(shares(user));
    }

    function shares(address user) public view virtual returns (uint256) {
        return strategyManager.stakerStrategyShares(user, IStrategyBase(address(this)));
    }

    function _tokenBalance() internal view virtual returns (uint256) {
        return underlyingToken.balanceOf(address(this));
    }

    uint256[100] private __gap;
}