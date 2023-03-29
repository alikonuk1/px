// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {Vault} from "./Vault.sol";
import {Ownable} from "./utils/Ownable.sol";
import {IProxy} from "./interfaces/IProxy.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {ITreasury} from "./interfaces/ITreasury.sol";

contract Px is Ownable {
    /////////////////////////////////////////////
    //                 Events
    /////////////////////////////////////////////

    event LiquidityAdded(address indexed provider, uint256 amountAdded, uint256 sharesMinted, bool isWeth);
    event LiquidityRemoved(address indexed provider, uint256 sharesBurned, bool isWeth);

    event Deposit(address indexed trader, uint256 amount);
    event Withdrawal(address indexed trader, uint256 amount);

    event PositionOpened(address indexed trader, uint256 size, int256 entryPrice, uint256 margin, bool isLong);
    event PositionClosed(address indexed trader, uint256 size, int256 exitPrice);
    event Liquidation(address indexed liquidator, address indexed trader, bool isWeth, uint256 liquidationFee);

    /////////////////////////////////////////////
    //                 Storage
    /////////////////////////////////////////////

    uint8 private mutex = 1;
    uint256 public fee = 3 * 10 ** 15; // 3000000000000000 = 0.3%
    uint256 public shareSupplyWeth;
    uint256 public shareSupplyUsdc;
    address public proxy;
    address public usdc;
    address public weth;
    address public treasury;

    /////////////////////////////////////////////
    //                 Structs
    /////////////////////////////////////////////

    struct Position {
        uint256 size;
        uint256 amountOut;
        int256 entryPrice;
        uint8 leverage;
        bool isLong;
        address vault;
        bool isWeth;
    }

    /////////////////////////////////////////////
    //                Mappings
    /////////////////////////////////////////////

    mapping(address => Position) public positions;
    mapping(address => uint256) public usdcBalances;
    mapping(address => uint256) public wethBalances;
    mapping(address => uint256) public providerWethShares;
    mapping(address => uint256) public providerUsdcShares;

    /////////////////////////////////////////////
    //                Modifiers
    /////////////////////////////////////////////

    modifier noReentrancy() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() internal {
        if (mutex != 1) {
            revert IErrors.REENTRANCY();
        }
        mutex = 2;
    }

    function _nonReentrantAfter() internal {
        mutex = 1;
    }

    /////////////////////////////////////////////
    //               Constructor
    /////////////////////////////////////////////
    constructor(address proxy_, address usdc_, address weth_, address treasury_) {
        setProxy(proxy_);
        usdc = usdc_;
        weth = weth_;
        treasury = treasury_;
    }

    /////////////////////////////////////////////
    //               Admin Stuff
    /////////////////////////////////////////////

    function setProxy(address proxy_) public onlyOwner {
        assembly {
            sstore(proxy.slot, proxy_)
        }
    }

    function setTreasury(address treasury_) public onlyOwner {
        assembly {
            sstore(treasury.slot, treasury_)
        }
    }

    function setFee(uint256 fee_) public onlyOwner {
        assembly {
            sstore(fee.slot, fee_)
        }
    }

    /////////////////////////////////////////////
    //               Liquidity
    /////////////////////////////////////////////

    function provideLiquidity(uint256 amount, bool isWeth) external payable noReentrancy {
        if (amount < 0.001 ether) {
            revert IErrors.DUST();
        }
        uint256 sharesMinted = amount;

        if (isWeth) {
            require(shareSupplyWeth + sharesMinted >= shareSupplyWeth, "Integer overflow detected");
            IERC20(weth).transferFrom(msg.sender, treasury, amount);
            providerWethShares[msg.sender] = providerWethShares[msg.sender] + sharesMinted;
            shareSupplyWeth = shareSupplyWeth + sharesMinted;
        } else {
            require(shareSupplyUsdc + sharesMinted >= shareSupplyUsdc, "Integer overflow detected");
            IERC20(usdc).transferFrom(msg.sender, treasury, amount);
            providerUsdcShares[msg.sender] = providerUsdcShares[msg.sender] + sharesMinted;
            shareSupplyUsdc = shareSupplyUsdc + sharesMinted;
        }

        emit LiquidityAdded(msg.sender, amount, sharesMinted, isWeth);
    }

    function withdrawLiquidity(uint256 shareAmount, bool isWeth) external noReentrancy {
        if (shareAmount == 0) {
            revert IErrors.ZERO();
        }

        if (isWeth) {
            require(shareAmount <= providerWethShares[msg.sender], "insufficient user balance");
            require(shareAmount <= shareSupplyWeth, "insufficient global supply");

            uint256 sharePer = (IERC20(weth).balanceOf(treasury) * 10 ** 18 / shareSupplyWeth);
            uint256 shareValue = (sharePer * (shareAmount)) / 10 ** 18;

            require(IERC20(weth).balanceOf(treasury) >= shareValue, "insufficient contract balance");

            providerWethShares[msg.sender] = providerWethShares[msg.sender] - shareAmount;
            shareSupplyWeth = shareSupplyWeth - shareAmount;

            ITreasury(treasury).moveOut(weth, msg.sender, shareValue);
        } else {
            require(shareAmount <= providerUsdcShares[msg.sender], "insufficient user balance");
            require(shareAmount <= shareSupplyUsdc, "insufficient global supply");

            uint256 sharePer = (IERC20(usdc).balanceOf(treasury) * 10 ** 6 / shareSupplyUsdc);
            uint256 shareValue = (sharePer * (shareAmount)) / 10 ** 6;

            require(IERC20(usdc).balanceOf(treasury) >= shareValue, "insufficient contract balance");

            providerUsdcShares[msg.sender] = providerUsdcShares[msg.sender] - shareAmount;
            shareSupplyUsdc = shareSupplyUsdc - shareAmount;

            ITreasury(treasury).moveOut(usdc, msg.sender, shareValue);
        }

        emit LiquidityRemoved(msg.sender, shareAmount, isWeth);
    }

    /////////////////////////////////////////////
    //               Collateral
    /////////////////////////////////////////////

    function deposit(uint256 amount, bool isWeth) external noReentrancy {
        if (isWeth) {
            IERC20(weth).transferFrom(msg.sender, address(this), amount);
            wethBalances[msg.sender] += amount;
        } else {
            IERC20(usdc).transferFrom(msg.sender, address(this), amount);
            usdcBalances[msg.sender] += amount;
        }

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount, bool isWeth) external noReentrancy {
        address token;

        if(isWeth){
            token = weth;
        } else {
            token = usdc;
        }

        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        require(tokenBalance >= amount, "Insufficient contract balance");

        if (isWeth) {
            require(wethBalances[msg.sender] >= amount, "Insufficient user balance");
            wethBalances[msg.sender] -= amount;
        } else {
            require(usdcBalances[msg.sender] >= amount, "Insufficient user balance");
            usdcBalances[msg.sender] -= amount;
        }

        IERC20(token).transfer(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    /////////////////////////////////////////////
    //              Trading Logic
    /////////////////////////////////////////////

    function openPosition(uint256 size, bool isLong, bool isWeth, uint8 leverage) external noReentrancy {
        (int224 currentPrice,) = readDataFeed();
        if (currentPrice == 0) {
            revert IErrors.ZERO();
        }
        if (leverage >= 11) {
            revert IErrors.MAX_LEVERAGE();
        }

        if (leverage == 0) {
            leverage = 1;
        }

        Vault vault = new Vault(address(this));

        uint256 sizeUsd;

        if (isWeth) {
            require(wethBalances[msg.sender] >= size, "Insufficient user balance");
            wethBalances[msg.sender] -= size;
            IERC20(weth).transfer(address(vault), size);
            sizeUsd = uint256(uint224(currentPrice)) * size;
        } else {
            require(usdcBalances[msg.sender] >= size, "Insufficient user balance");
            usdcBalances[msg.sender] -= size;
            IERC20(usdc).transfer(address(vault), size);
            sizeUsd = size;
        }

        uint256 leveragedUsd = sizeUsd * leverage;
        uint256 leveragedWeth = size * leverage;

        require(IERC20(usdc).balanceOf(treasury) > size * leverage, "Not enough USDC in treasury");
        require(IERC20(weth).balanceOf(treasury) > leveragedWeth, "Not enough WETH in treasury");

        Position storage position = positions[msg.sender];
        position.size = size;
        position.entryPrice = currentPrice;
        position.leverage = leverage;
        position.isLong = isLong;
        position.isWeth = isWeth;
        position.vault = address(vault);

        if (isLong) {
            uint256 amountOut = ITreasury(treasury).swapTokens(usdc, weth, leveragedUsd);
            ITreasury(treasury).moveOut(weth, address(vault), amountOut);
            position.amountOut = amountOut;
        } else {
            uint256 amountOut = ITreasury(treasury).swapTokens(weth, usdc, leveragedWeth);
            ITreasury(treasury).moveOut(usdc, address(vault), amountOut);
            position.amountOut = amountOut;
        }

        emit PositionOpened(msg.sender, size, currentPrice, leverage, isLong);
    }

    function closePosition() external noReentrancy {
        Position storage position = positions[msg.sender];
        if (position.size == 0) {
            revert IErrors.NO_POSITION();
        }

        address vault = position.vault;
        bool isWeth = position.isWeth;
        bool isLong = position.isLong;
        uint256 amountOut = position.amountOut;

        (int224 currentPrice,) = readDataFeed();
        if (currentPrice == 0) {
            revert IErrors.ZERO();
        }

        int256 pnl = calculatePnL(position.entryPrice, currentPrice, position.size, position.isLong);
        uint256 exitSize = position.size + uint256(pnl);
        uint256 fee_ = exitSize / fee;
        uint256 exitSize_ = exitSize - fee_;

        position.size = 0;
        position.entryPrice = 0;
        position.leverage = 0;
        position.isLong = false;
        position.vault = address(0);
        position.isWeth = false;

        if (isLong) {
            if (isWeth) {
                IVault(vault).moveOut(weth, treasury, fee_);
                ITreasury(treasury).swapTokens(weth, usdc, fee_);
                IVault(vault).moveOut(weth, address(this), exitSize_);
                wethBalances[msg.sender] += exitSize_;
            } else {
                IVault(vault).moveOut(usdc, treasury, fee_);
                IVault(vault).moveOut(usdc, address(this), exitSize_);
                usdcBalances[msg.sender] += exitSize_;
            }
            IVault(vault).moveOut(weth, treasury, amountOut);
            ITreasury(treasury).swapTokens(weth, usdc, amountOut);
        } else {
            if (isWeth) {
                IVault(vault).moveOut(weth, treasury, fee_);
                IVault(vault).moveOut(weth, address(this), exitSize_);
                wethBalances[msg.sender] += exitSize_;
            } else {
                IVault(vault).moveOut(usdc, treasury, fee_);
                ITreasury(treasury).swapTokens(usdc, weth, fee_);
                IVault(vault).moveOut(usdc, address(this), exitSize_);
                usdcBalances[msg.sender] += exitSize_;
            }
            IVault(vault).moveOut(usdc, treasury, amountOut);
            ITreasury(treasury).swapTokens(usdc, weth, amountOut);
        }

        emit PositionClosed(msg.sender, exitSize, currentPrice);
    }

    function liquidate(address trader) external noReentrancy {
        Position storage position = positions[trader];
        if (position.size == 0) {
            revert IErrors.NO_POSITION();
        }

        (int224 currentPrice, uint256 timestamp) = readDataFeed();
        if (currentPrice == 0) {
            revert IErrors.ZERO();
        }
        require(timestamp + 1 days > block.timestamp, "Timestamp older than one day");

        address vault = position.vault;
        bool isWeth = position.isWeth;
        bool isLong = position.isLong;
        uint256 amountOut = position.amountOut;
        uint8 leverage = position.leverage;
        uint256 size = position.size;

        int256 pnl = calculatePnL(position.entryPrice, currentPrice, size, isLong);

        uint256 sizeAfterPnL;

        if (pnl > 0) {
            sizeAfterPnL = size + uint256(pnl);
        } else {
            sizeAfterPnL = size - uint256(-pnl);
        }

        uint256 liquidationThreshold = (size * leverage) / 100;

        if (sizeAfterPnL >= liquidationThreshold) {
            revert IErrors.NOT_UNDERMARGINED();
        }

        position.size = 0;
        position.entryPrice = 0;
        position.leverage = 0;
        position.isLong = false;
        position.vault = address(0);
        position.isWeth = false;

        if (isLong) {
            IVault(vault).moveOut(weth, treasury, amountOut);
            ITreasury(treasury).swapTokens(weth, usdc, amountOut);
        } else {
            IVault(vault).moveOut(usdc, treasury, amountOut);
            ITreasury(treasury).swapTokens(usdc, weth, amountOut);
        }

        if (isWeth) {
            IVault(vault).moveOut(weth, msg.sender, sizeAfterPnL);
        } else {
            IVault(vault).moveOut(usdc, msg.sender, sizeAfterPnL);
        }

        emit Liquidation(msg.sender, trader, isWeth, sizeAfterPnL);
    }

    function calculatePnL(int256 entryPrice, int256 exitPrice, uint256 size, bool isLong)
        public
        pure
        returns (int256)
    {
        int256 priceDifference = exitPrice - entryPrice;
        if (isLong) {
            return (priceDifference * int256(size));
        } else {
            return (-priceDifference * int256(size));
        }
    }

    function isSolvent(address trader) public view returns (bool, uint256) {
        Position storage position = positions[trader];
        if (position.size == 0) {
            revert IErrors.NO_POSITION();
        }

        (int224 currentPrice, uint256 timestamp) = readDataFeed();
        if (currentPrice == 0) {
            revert IErrors.ZERO();
        }
        require(timestamp + 1 days > block.timestamp, "Timestamp older than one day");

        bool isLong = position.isLong;
        uint8 leverage = position.leverage;
        uint256 size = position.size;

        int256 pnl = calculatePnL(position.entryPrice, currentPrice, size, isLong);

        uint256 sizeAfterPnL;

        if (pnl > 0) {
            sizeAfterPnL = size + uint256(pnl);
        } else {
            sizeAfterPnL = size - uint256(-pnl);
        }

        uint256 liquidationThreshold = (size * leverage) / 100;

        if (sizeAfterPnL < liquidationThreshold) {
            return (true, 0);
        } else {
            return (false, sizeAfterPnL);
        }
    }

    /////////////////////////////////////////////
    //                 Oracle
    /////////////////////////////////////////////

    function readDataFeed() public view returns (int224 value, uint256 timestamp) {
        (value, timestamp) = IProxy(proxy).read();
    }
}
