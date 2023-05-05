// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error CustomToken__NotOwner();
error CustomToken__MintToTheZeroAddress();
error CustomToken__TransferFromTheZeroAddress();
error CustomToken__TransferToTheZeroAddress();
error CustomToken__TransferAmountExceedsBalance();
error CustomToken__ApproveFromTheZeroAddress();
error CustomToken__ApproveToTheZeroAddress();
error CustomToken__InsufficientAllowance();
error CustomToken__BurnToTheZeroAddress();
error CustomToken__BurnAmountExceedsBalance();
error CustomToken__DecreasedAllowanceBelowZero();

/**@title A sample ERC20 token contract
 * @author Chuong Thai
 */
contract CustomToken is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    string private _name;
    string private _symbol;
    address private immutable i_owner;
    uint256 private _totalSupply;

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert CustomToken__NotOwner();
        _;
    }

    constructor(string memory tokenName, string memory tokenSymbol, uint256 amount) {
        _name = tokenName;
        _symbol = tokenSymbol;
        i_owner = msg.sender;
        _mint(i_owner, amount);
    }

    function name() external view virtual returns (string memory) {
        return _name;
    }

    function symbol() external view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() external pure virtual returns (uint8) {
        return 18;
    }

    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external virtual override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external virtual override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < subtractedValue) revert CustomToken__DecreasedAllowanceBelowZero();

        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert CustomToken__MintToTheZeroAddress();
        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) revert CustomToken__TransferFromTheZeroAddress();
        if (to == address(0)) revert CustomToken__TransferToTheZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert CustomToken__TransferAmountExceedsBalance();

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        if (owner == address(0)) revert CustomToken__ApproveFromTheZeroAddress();
        if (spender == address(0)) revert CustomToken__ApproveToTheZeroAddress();

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance == type(uint256).max) return;
        if (currentAllowance < amount) revert CustomToken__InsufficientAllowance();

        unchecked {
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    function _burn(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert CustomToken__BurnToTheZeroAddress();
        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) revert CustomToken__BurnAmountExceedsBalance();

        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }
}
