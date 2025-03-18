// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract MyERC20Token {
    // 代币名称
    string private _name;
    // 代币符号
    string private _symbol;
    // 代币小数位数，通常为 18
    uint8 private constant _decimals = 18;
    // 总供应量
    uint256 private _totalSupply;
    // 每个地址的余额映射
    mapping(address => uint256) private _balances;
    // 授权额度映射，记录一个地址允许另一个地址动用的代币数量
    mapping(address => mapping(address => uint256)) private _allowances;

    // 定义最大供应量为 1 亿个代币
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18;
    // 定义初始分配给 msg.sender 的代币数量为 100 万个
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    // 转账事件，当发生代币转账时触发
    event Transfer(address indexed from, address indexed to, uint256 value);
    // 授权事件，当设置或更改授权额度时触发
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // 添加所有者变量
    address private _owner;
   
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _owner = msg.sender; // 设置合约部署者为所有者
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // 获取代币名称
    function name() public view returns (string memory) {
        return _name;
    }

    // 获取代币符号
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    // 获取代币小数位数
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    // 获取总供应量
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // 获取指定地址的余额
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    // 转账函数，将调用者的代币转账给指定地址
    function transfer(address to, uint256 amount) public returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    // 获取一个地址允许另一个地址动用的代币数量
    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    // 设置授权额度，允许指定地址动用调用者的一定数量代币
    function approve(address spender, uint256 amount) public returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    // 由被授权地址进行代币转账
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    // 增加授权额度
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    // 减少授权额度
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = _allowances[owner][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    // 铸造代币的函数，任何人都可以调用
    function mint(address to, uint256 amount) external {
        // 检查铸造指定数量的代币后是否会超过最大供应量
        require(_totalSupply + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
    }

    // 内部转账函数
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 fromBalance = _balances[from];
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    // 内部铸造函数
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    // 内部授权函数
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // 内部消耗授权额度函数
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    // 添加 burn 函数（可选）
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}
