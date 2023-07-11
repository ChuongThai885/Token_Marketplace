// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20Extended.sol";

error TokenMarketplace__InsufficientAmount();
error TokenMarketplace__InvalidPrice();
error TokenMarketplace__InsufficientAllowance();
error TokenMarketplace__NotOwner();
error TokenMarketplace__SellOrderExisted();
error TokenMarketplace__BuyOrderExisted();
error TokenMarketplace__BuyOrderNotExist();
error TokenMarketplace__SellOrderNotExist();
error TokenMarketplace__InvalidIndex();

/**
 * @title A simple version of token marketplace
 * @author Chuong Thai
 * @notice This contract for creating a token marketplace with simple order matching algorithm
 */
contract TokenMarketplace {
    struct UserOrder {
        address owner;
        address tokenAddress;
    }
    struct OrderDetail {
        uint256 amount;
        uint256 price;
    }

    event OrderPlaced(
        address indexed owner,
        address indexed tokenAddress,
        uint256 amount,
        uint256 price,
        bool isBuyOrder,
        uint256 timestamp
    );
    event OrderMatched(
        address indexed owner,
        address indexed traderMatched,
        address indexed tokenAddress,
        uint256 amount,
        uint256 price,
        bool isBuyOrder,
        uint256 timestamp
    );
    event OrderCanceled(
        address indexed owner,
        address indexed tokenAddress,
        bool isBuyOrder,
        uint256 timestamp
    );

    UserOrder[] private _userSellOrders;
    UserOrder[] private _userBuyOrders;
    mapping(address => mapping(address => OrderDetail)) private _sellOrderDetailBook;
    mapping(address => mapping(address => OrderDetail)) private _buyOrderDetailBook;

    /**
     * @dev Place a sell order to sell order book
     * Takes tokens from sender
     * Emits a {OrderPlaced} event
     */
    function placeSellOrder(address tokenAddress, uint256 amount, uint256 totalPrice) external {
        OrderDetail storage sellOrderDetailBook = _sellOrderDetailBook[msg.sender][tokenAddress];
        if (_isExistingOrder(sellOrderDetailBook)) revert TokenMarketplace__SellOrderExisted();
        IERC20Extended token = IERC20Extended(tokenAddress);
        uint256 price = _getPrice(token, amount, totalPrice);

        if (token.allowance(msg.sender, address(this)) < amount)
            revert TokenMarketplace__InsufficientAllowance();
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

        _userSellOrders.push(UserOrder(msg.sender, tokenAddress));
        sellOrderDetailBook.amount = amount;
        sellOrderDetailBook.price = price;

        emit OrderPlaced(msg.sender, tokenAddress, amount, price, false, block.timestamp);

        _matchOrder(msg.sender, tokenAddress, false);
    }

    /**
     * @dev Place a buy order to sell order book
     * Takes money from sender
     * Emits a {OrderPlaced} event
     */
    function placeBuyOrder(address tokenAddress, uint256 amount) external payable {
        OrderDetail storage buyOrderDetailBook = _buyOrderDetailBook[msg.sender][tokenAddress];
        if (_isExistingOrder(buyOrderDetailBook)) revert TokenMarketplace__BuyOrderExisted();
        IERC20Extended token = IERC20Extended(tokenAddress);
        uint256 price = _getPrice(token, amount, msg.value);

        _userBuyOrders.push(UserOrder(msg.sender, tokenAddress));
        buyOrderDetailBook.amount = amount;
        buyOrderDetailBook.price = price;

        emit OrderPlaced(msg.sender, tokenAddress, amount, price, true, block.timestamp);

        _matchOrder(msg.sender, tokenAddress, true);
    }

    /**
     * @dev remove order out of order book and send back money or token to owner
     */
    function cancelOrder(address owner, address tokenAddress, bool isBuyOrder) external {
        if (msg.sender != owner) revert TokenMarketplace__NotOwner();
        UserOrder[] memory orderBook = isBuyOrder ? _userBuyOrders : _userSellOrders;
        OrderDetail memory orderDetailBook = isBuyOrder
            ? _buyOrderDetailBook[owner][tokenAddress]
            : _sellOrderDetailBook[owner][tokenAddress];
        if (!_isExistingOrder(orderDetailBook)) {
            if (isBuyOrder) revert TokenMarketplace__BuyOrderNotExist();
            else revert TokenMarketplace__SellOrderNotExist();
        }

        for (uint256 index = 0; index < orderBook.length; index += 1) {
            if (orderBook[index].owner != owner || orderBook[index].tokenAddress != tokenAddress)
                continue;

            if (isBuyOrder) {
                _transferBuyMoney(owner, owner, tokenAddress, orderDetailBook.amount);
            } else {
                _transferSaleToken(owner, tokenAddress, orderDetailBook.amount);
            }
            _removeOrder(owner, tokenAddress, orderBook, index, isBuyOrder);
            break;
        }
    }

    /**
     * @dev return detail sell order
     */
    function getDetailSellOrder(
        address owner,
        address tokenAddress
    ) external view returns (OrderDetail memory) {
        OrderDetail memory orderDetailBook = _sellOrderDetailBook[owner][tokenAddress];
        if (!_isExistingOrder(orderDetailBook)) revert TokenMarketplace__SellOrderNotExist();
        return orderDetailBook;
    }

    /**
     * @dev return detail buy order
     */
    function getDetailBuyOrder(
        address owner,
        address tokenAddress
    ) external view returns (OrderDetail memory) {
        OrderDetail memory orderDetailBook = _buyOrderDetailBook[owner][tokenAddress];
        if (!_isExistingOrder(orderDetailBook)) revert TokenMarketplace__BuyOrderNotExist();
        return orderDetailBook;
    }

    /**
     * @dev return number of buy order
     */
    function getBuyOrderCount() external view returns (uint256) {
        return _userBuyOrders.length;
    }

    /**
     * @dev return number of sell order
     */
    function getSellOrderCount() external view returns (uint256) {
        return _userSellOrders.length;
    }

    /**
     * @dev return user order
     */
    function getUserOrder(
        uint256 orderIndex,
        bool isBuyOrder
    ) external view returns (UserOrder memory) {
        uint256 orderLength = isBuyOrder ? _userBuyOrders.length : _userSellOrders.length;
        if (orderIndex >= orderLength) revert TokenMarketplace__InvalidIndex();
        return isBuyOrder ? _userBuyOrders[orderIndex] : _userSellOrders[orderIndex];
    }

    /**
     * @dev check if order is still on orderbook
     */
    function isOnOrderBook(
        address owner,
        address tokenAddress,
        bool isBuyOrder
    ) external view returns (bool) {
        UserOrder[] memory userOrder = isBuyOrder ? _userBuyOrders : _userSellOrders;
        bool isOnOrder = false;
        for (uint256 index = 0; index < userOrder.length; index += 1) {
            UserOrder memory order = userOrder[index];
            if (order.owner != owner || order.tokenAddress != tokenAddress) continue;
            isOnOrder = true;
            break;
        }
        return isOnOrder;
    }

    /**
     * @dev check if order is existing or not
     */
    function _isExistingOrder(OrderDetail memory orderDetailBook) internal pure returns (bool) {
        return orderDetailBook.price != 0 || orderDetailBook.amount != 0;
    }

    /**
     * @dev simple order matching algorithm
     * Make buy and sell order with the same price matched
     * Loop until the amount token of order sent to equal 0 or no buy or sell order have the same price
     * Remove all order has amount=0 out of order book
     * Emit {OrderMatched} event
     */
    function _matchOrder(address owner, address tokenAddress, bool isBuyOrder) internal {
        OrderDetail storage order = isBuyOrder
            ? _buyOrderDetailBook[owner][tokenAddress]
            : _sellOrderDetailBook[owner][tokenAddress];
        UserOrder[] memory userOrders = isBuyOrder ? _userSellOrders : _userBuyOrders;

        for (uint256 i = 0; i < userOrders.length; i += 1) {
            UserOrder memory potentialUserOrder = userOrders[i];
            OrderDetail memory potentialOrderMatch = isBuyOrder
                ? _sellOrderDetailBook[potentialUserOrder.owner][potentialUserOrder.tokenAddress]
                : _buyOrderDetailBook[potentialUserOrder.owner][potentialUserOrder.tokenAddress];
            if (order.price != potentialOrderMatch.price) continue;

            uint256 tradeAmount = _getMininum(order.amount, potentialOrderMatch.amount);
            address buyer = isBuyOrder ? owner : potentialUserOrder.owner;
            address seller = isBuyOrder ? potentialUserOrder.owner : owner;
            _transferSaleToken(buyer, tokenAddress, tradeAmount);
            _transferBuyMoney(buyer, seller, tokenAddress, tradeAmount);

            unchecked {
                if (isBuyOrder) {
                    _sellOrderDetailBook[potentialUserOrder.owner][potentialUserOrder.tokenAddress]
                        .amount -= tradeAmount;
                } else {
                    _buyOrderDetailBook[potentialUserOrder.owner][potentialUserOrder.tokenAddress]
                        .amount -= tradeAmount;
                }
                order.amount -= tradeAmount;
            }

            emit OrderMatched(
                owner,
                potentialUserOrder.owner,
                tokenAddress,
                tradeAmount,
                order.price,
                isBuyOrder,
                block.timestamp
            );
            if (potentialOrderMatch.amount - tradeAmount == 0) {
                _removeOrder(potentialUserOrder.owner, tokenAddress, userOrders, i, !isBuyOrder);
            }
            if (order.amount == 0) {
                _removeOrder(
                    owner,
                    tokenAddress,
                    isBuyOrder ? _userBuyOrders : _userSellOrders,
                    0,
                    isBuyOrder
                );
                break;
            }
        }
    }

    /**
     * @dev remove Order from order book
     * Emit a {OrderCanceled} event
     */
    function _removeOrder(
        address owner,
        address tokenAddress,
        UserOrder[] memory orderBook,
        uint256 index,
        bool isBuyOrder
    ) internal {
        for (; index < orderBook.length; index += 1) {
            if (orderBook[index].owner != owner || orderBook[index].tokenAddress != tokenAddress)
                continue;
            // delete order
            UserOrder[] storage _orderBook = isBuyOrder ? _userBuyOrders : _userSellOrders;
            for (; index < orderBook.length - 1; index += 1) {
                _orderBook[index] = orderBook[index + 1];
            }
            delete _orderBook[orderBook.length - 1];
            _orderBook.pop();

            if (isBuyOrder) {
                delete _buyOrderDetailBook[owner][tokenAddress];
            } else {
                delete _sellOrderDetailBook[owner][tokenAddress];
            }
            emit OrderCanceled(owner, tokenAddress, isBuyOrder, block.timestamp);
            break;
        }
    }

    /**
     * @dev transfer token with amount
     */
    function _transferSaleToken(address to, address tokenAddress, uint256 amount) internal {
        IERC20Extended(tokenAddress).transfer(to, amount);
    }

    /**
     * @dev transfer money base on token amount and price in order book
     */
    function _transferBuyMoney(
        address owner,
        address to,
        address tokenAddress,
        uint amount
    ) internal {
        uint256 totalPrice;
        unchecked {
            totalPrice =
                _buyOrderDetailBook[owner][tokenAddress].price *
                (amount / (10 ** IERC20Extended(tokenAddress).decimals()));
        }
        (bool callSuccess, ) = payable(to).call{value: totalPrice}("");
        require(callSuccess);
    }

    /**
     * @dev check msg.value is valid
     * Return price for each token base on amount
     */
    function _getPrice(
        IERC20Extended token,
        uint256 amount,
        uint256 totalPrice
    ) internal view returns (uint256) {
        uint256 decimals;
        unchecked {
            decimals = (10 ** token.decimals());
        }
        if (amount == 0 || amount % decimals != 0) revert TokenMarketplace__InsufficientAmount();
        uint256 _amount;
        unchecked {
            _amount = amount / decimals;
        }
        if (totalPrice == 0 || totalPrice % _amount != 0) revert TokenMarketplace__InvalidPrice();
        unchecked {
            return totalPrice / _amount;
        }
    }

    /**
     * @dev helper function return min between 2 numbers
     */
    function _getMininum(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
