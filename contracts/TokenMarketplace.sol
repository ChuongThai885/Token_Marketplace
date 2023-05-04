// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20Extended.sol";

error TokenMarketplace__InsufficientAmount();
error TokenMarketplace__InvalidPrice();
error TokenMarketplace__InsufficientAllowance();
error TokenMarketplace__NotOwner();

/**
 * @title A simple version of token marketplace
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
        bool isBuyOrder
    );
    event OrderMatched(
        address indexed owner,
        address indexed traderMatched,
        address indexed tokenAddress,
        uint256 amount,
        uint256 price,
        bool isBuyOrder
    );
    event OrderCanceled(address indexed owner, address indexed tokenAddress, bool isBuyOrder);

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
        IERC20Extended token = IERC20Extended(tokenAddress);
        uint256 price = _getPrice(token, amount, totalPrice);

        if (token.allowance(msg.sender, address(this)) < amount)
            revert TokenMarketplace__InsufficientAllowance();
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

        _userSellOrders.push(UserOrder(msg.sender, tokenAddress));
        _sellOrderDetailBook[msg.sender][tokenAddress] = OrderDetail(amount, price);

        emit OrderPlaced(msg.sender, tokenAddress, amount, price, false);

        matchOrder(msg.sender, tokenAddress, false);
    }

    /**
     * @dev Place a buy order to sell order book
     * Takes money from sender
     * Emits a {OrderPlaced} event
     */
    function placeBuyOrder(address tokenAddress, uint256 amount) external payable {
        IERC20Extended token = IERC20Extended(tokenAddress);
        uint256 price = _getPrice(token, amount, msg.value);

        _userBuyOrders.push(UserOrder(msg.sender, tokenAddress));
        _buyOrderDetailBook[msg.sender][tokenAddress] = OrderDetail(amount, price);

        emit OrderPlaced(msg.sender, tokenAddress, amount, price, true);

        matchOrder(msg.sender, tokenAddress, true);
    }

    /**
     * @dev simple order matching algorithm
     * Make buy and sell order with the same price matched
     * Loop until the amount token of order sent to equal 0 or no buy or sell order have the same price
     * Remove all order has amount=0 out of order book
     * Emit {OrderMatched} event
     */
    function matchOrder(address owner, address tokenAddress, bool isBuyOrder) internal {
        OrderDetail storage order = isBuyOrder
            ? _buyOrderDetailBook[owner][tokenAddress]
            : _sellOrderDetailBook[owner][tokenAddress];
        UserOrder[] storage userOrders = isBuyOrder ? _userSellOrders : _userBuyOrders;

        for (uint256 i = 0; i < userOrders.length; i += 1) {
            UserOrder memory potentialUserOrder = userOrders[i];
            OrderDetail storage potentialOrderMatch = isBuyOrder
                ? _sellOrderDetailBook[potentialUserOrder.owner][potentialUserOrder.tokenAddress]
                : _buyOrderDetailBook[potentialUserOrder.owner][potentialUserOrder.tokenAddress];
            if (order.price != potentialOrderMatch.price) continue;

            uint256 tradeAmount = _getMininum(order.amount, potentialOrderMatch.amount);
            address buyer = isBuyOrder ? owner : potentialUserOrder.owner;
            address seller = isBuyOrder ? potentialUserOrder.owner : owner;
            _transferSaleToken(buyer, tokenAddress, tradeAmount);
            _transferBuyMoney(buyer, seller, tokenAddress, tradeAmount);
            potentialOrderMatch.amount -= tradeAmount;
            order.amount -= tradeAmount;

            emit OrderMatched(
                owner,
                potentialUserOrder.owner,
                tokenAddress,
                tradeAmount,
                order.price,
                isBuyOrder
            );
            if (potentialOrderMatch.amount == 0) {
                _removeOrder(potentialUserOrder.owner, tokenAddress, userOrders, i, !isBuyOrder);
            }
            if (order.amount == 0) {
                _removeOrder(owner, tokenAddress, userOrders, 0, isBuyOrder);
                break;
            }
        }
    }

    /**
     * @dev remove order out of order book and send back money or token to owner
     */
    function cancelOrder(address owner, address tokenAddress, bool isBuyOrder) external {
        if (msg.sender != owner) revert TokenMarketplace__NotOwner();
        UserOrder[] storage orderBook = isBuyOrder ? _userBuyOrders : _userSellOrders;
        uint256 index;
        for (index = 0; index < orderBook.length; index += 1) {
            if (orderBook[index].owner != owner || orderBook[index].tokenAddress != tokenAddress)
                continue;

            if (isBuyOrder) {
                _transferBuyMoney(
                    owner,
                    owner,
                    tokenAddress,
                    _buyOrderDetailBook[owner][tokenAddress].amount
                );
            } else {
                _transferSaleToken(
                    owner,
                    tokenAddress,
                    _sellOrderDetailBook[owner][tokenAddress].amount
                );
            }
            _removeOrder(owner, tokenAddress, orderBook, index, isBuyOrder);
            break;
        }
    }

    /**
     * @dev remove Order from order book
     * Emit a {OrderCanceled} event
     */
    function _removeOrder(
        address owner,
        address tokenAddress,
        UserOrder[] storage orderBook,
        uint256 index,
        bool isBuyOrder
    ) internal {
        for (; index < orderBook.length; index += 1) {
            if (orderBook[index].owner != owner || orderBook[index].tokenAddress != tokenAddress)
                continue;
            // delete order
            for (; index < orderBook.length - 1; index += 1) {
                orderBook[index] = orderBook[index + 1];
            }
            delete orderBook[orderBook.length - 1];
            orderBook.pop();

            if (isBuyOrder) {
                delete _buyOrderDetailBook[owner][tokenAddress];
            } else {
                delete _sellOrderDetailBook[owner][tokenAddress];
            }
            emit OrderCanceled(owner, tokenAddress, isBuyOrder);
            break;
        }
    }

    /**
     * @dev return detail sell order
     */
    function getSellOrder(
        address owner,
        address tokenAddress
    ) external view returns (OrderDetail memory) {
        return _sellOrderDetailBook[owner][tokenAddress];
    }

    /**
     * @dev return detail buy order
     */
    function getBuyOrder(
        address owner,
        address tokenAddress
    ) external view returns (OrderDetail memory) {
        return _buyOrderDetailBook[owner][tokenAddress];
    }

    /**
     * @dev transfer token with amount
     */
    function _transferSaleToken(address to, address tokenAddress, uint256 amount) internal {
        IERC20Extended(tokenAddress).transfer(to, amount);
    }

    /**
     * dev transfer money base on token amount and price in order book
     */
    function _transferBuyMoney(
        address owner,
        address to,
        address tokenAddress,
        uint amount
    ) internal {
        (bool callSuccess, ) = payable(to).call{
            value: (_buyOrderDetailBook[owner][tokenAddress].price * amount) /
                IERC20Extended(tokenAddress).decimals()
        }("");
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
        if (amount < 0 || amount % token.decimals() != 0)
            revert TokenMarketplace__InsufficientAmount();
        uint256 _amount = amount / token.decimals();
        if (totalPrice < 0 || totalPrice % _amount != 0) revert TokenMarketplace__InvalidPrice();
        return totalPrice / _amount;
    }

    /**
     * @dev helper function return min between 2 numbers
     */
    function _getMininum(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
