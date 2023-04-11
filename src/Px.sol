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

    function provideLiquidity(uint256 amount, bool isWeth) external noReentrancy {
        uint256 sharesMinted = amount;

        if (isWeth) {
            if (amount < 0.001 ether) {
                revert IErrors.DUST();
            }
            require(shareSupplyWeth + sharesMinted >= shareSupplyWeth, "Integer overflow detected");
            IERC20(weth).transferFrom(msg.sender, treasury, amount);
            providerWethShares[msg.sender] = providerWethShares[msg.sender] + sharesMinted;
            shareSupplyWeth = shareSupplyWeth + sharesMinted;
        } else {
            if (amount < 100000) {
                revert IErrors.DUST();
            }
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

        if (isWeth) {
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
        Position storage positionCheck = positions[msg.sender];
        if (positionCheck.size != 0) {
            revert IErrors.OPEN_POSITION_LEFT();
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
        int256 entryPrice = position.entryPrice;
        uint256 size = position.size;

        (int224 currentPrice,) = readDataFeed();
        if (currentPrice == 0) {
            revert IErrors.ZERO();
        }

        int256 pnl = calculatePnL(entryPrice, currentPrice, position.size, isLong, position.leverage);
        uint256 exitSize;
        uint256 pnl_;
        uint256 fee_;
        uint256 size_;
        if (pnl > 0) {
            exitSize = size + uint256(pnl);
            fee_ = exitSize / fee;
            size_ = size - fee_;
        } else {
            exitSize = size - uint256(-pnl);
            fee_ = exitSize / fee;
            size_ = exitSize - fee_;
        }

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
                IVault(vault).moveOut(weth, address(this), size_);
                wethBalances[msg.sender] += size_;
            } else {
                IVault(vault).moveOut(usdc, treasury, fee_);
                IVault(vault).moveOut(usdc, address(this), size_);
                usdcBalances[msg.sender] += size_;
            }
            IVault(vault).moveOut(weth, treasury, amountOut);
            uint256 amountOut_ = ITreasury(treasury).swapTokens(weth, usdc, amountOut);
            if (pnl > 0) {
                pnl_ = amountOut_ - amountOut;
                ITreasury(treasury).moveOut(usdc, address(this), pnl_);
                usdcBalances[msg.sender] += pnl_;
            } else {
                pnl_ = 0;
            }
        } else {
            if (isWeth) {
                IVault(vault).moveOut(weth, treasury, fee_);
                IVault(vault).moveOut(weth, address(this), size_);
                wethBalances[msg.sender] += size_;
            } else {
                IVault(vault).moveOut(usdc, treasury, fee_);
                ITreasury(treasury).swapTokens(usdc, weth, fee_);
                IVault(vault).moveOut(usdc, address(this), size_);
                usdcBalances[msg.sender] += size_;
            }
            IVault(vault).moveOut(usdc, treasury, amountOut);
            uint256 amountOut_ = ITreasury(treasury).swapTokens(usdc, weth, amountOut);
            if (pnl > 0) {
                pnl_ = amountOut_ - amountOut;
                ITreasury(treasury).moveOut(usdc, address(this), pnl_);
                wethBalances[msg.sender] += pnl_;
            } else {
                pnl_ = 0;
            }
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
        uint8 leverage = position.leverage;
        uint256 size = position.size;

        int256 pnl = calculatePnL(position.entryPrice, currentPrice, size, isLong, leverage);

        int256 sizeAfterPnL;

        if (pnl > 0) {
            sizeAfterPnL = int256(size + uint256(pnl));
            if (isWeth) {
                IVault(vault).moveOut(weth, msg.sender, uint256(sizeAfterPnL));
            } else {
                IVault(vault).moveOut(usdc, msg.sender, uint256(sizeAfterPnL));
            }
        } else {
            sizeAfterPnL = int256(size) + pnl;
        }

        uint256 liquidationThreshold = (size * leverage) / 100;

        if (sizeAfterPnL >= int256(liquidationThreshold)) {
            revert IErrors.NOT_UNDERMARGINED();
        } else {
            position.size = 0;
            position.entryPrice = 0;
            position.leverage = 0;
            position.isLong = false;
            position.vault = address(0);
            position.isWeth = false;

            if (isLong) {
                uint256 amount_ = IERC20(weth).balanceOf(address(vault));
                IVault(vault).moveOut(weth, treasury, amount_);
                ITreasury(treasury).swapTokens(weth, usdc, amount_);
            } else {
                uint256 amount_ = IERC20(usdc).balanceOf(address(vault));
                IVault(vault).moveOut(usdc, treasury, amount_);
                ITreasury(treasury).swapTokens(usdc, weth, amount_);
            }

            emit Liquidation(msg.sender, trader, isWeth, uint256(sizeAfterPnL));
        }
    }

    function calculatePnL(int256 entryPrice, int256 exitPrice, uint256 size, bool isLong, uint8 lev)
        public
        pure
        returns (int256)
    {
        int256 priceDifference = exitPrice - entryPrice;
        if (isLong) {
            return (priceDifference * int256(size) * int8(lev));
        } else {
            return (-priceDifference * int256(size) * int8(lev));
        }
    }

    function calculatePnLOf(address trader) public view returns (int256) {
        Position storage position = positions[trader];

        (int224 currentPrice, uint256 timestamp) = readDataFeed();
        if (currentPrice == 0) {
            revert IErrors.ZERO();
        }
        require(timestamp + 1 days > block.timestamp, "Timestamp older than one day");

        bool isLong = position.isLong;
        uint8 lev = position.leverage;
        uint256 size = position.size;

        int256 pnl = calculatePnL(position.entryPrice, currentPrice, size, isLong, lev);

        return (pnl);
    }

    function isSolvent(address trader) public view returns (bool) {
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

        int256 pnl = calculatePnL(position.entryPrice, currentPrice, size, isLong, leverage);

        int256 sizeAfterPnL;

        if (pnl > 0) {
            sizeAfterPnL = int256(size + uint256(pnl));
        } else {
            sizeAfterPnL = int256(size) + pnl;
        }

        uint256 liquidationThreshold = (size * leverage) / 100;

        if (sizeAfterPnL < int256(liquidationThreshold)) {
            return (false);
        } else {
            return (true);
        }
    }

    /////////////////////////////////////////////
    //                 Oracle
    /////////////////////////////////////////////

    function readDataFeed() public view returns (int224 value, uint256 timestamp) {
        (value, timestamp) = IProxy(proxy).read();
    }
}
