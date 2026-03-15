// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract MiniToken {
    string public name; // 代币名称
    string public symbol; // 代币符号
    uint8 public immutable decimals; // 小数位数

    uint256 public totalSupply; // 总供应量
    mapping(address => uint256) public balanceOf; //账户余额
    mapping(address => mapping(address => uint256)) public allowance; // 授权额度

    address public owner; // 合约管理员


    event Transfer(address indexed from, address indexed to, uint256 value); // 转账事件
    event Approval(address indexed owner, address indexed spender, uint256 value); // 授权事件
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner); // 所有权转移事件

    error ZeroAddress(); // 地址不能为零
    error InsufficientBalance(); // 余额不足
    error InsufficientAllowance();  // 授权额度不足
    error NotOwner(); // 非管理员操作

    // 权限控制
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(); 
        _;
    }
    // 构造函数，初始化代币信息和合约管理员
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    // ================= External =================

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value); // 调用内部转账函数
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < value) revert InsufficientAllowance();

        if (allowed != type(uint256).max) { // 如果不是无限授权，则扣减额度
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        _transfer(from, to, value); // 调用内部转账函数
        return true;
    }


    /// @notice 只有合约管理员才能铸币
    function mint(address to, uint256 value) external onlyOwner {
        _mint(to, value);// 调用内部铸币函数
    }

    /// @notice 可选：管理员销毁（很多项目不开）
    function burn(address from, uint256 value) external onlyOwner {
        _burn(from, value);// 调用内部销毁函数
    }


    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ================= Internal =================

    function _transfer(address from, address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < value) revert InsufficientBalance();

        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        if (from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < value) revert InsufficientBalance();
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }
}