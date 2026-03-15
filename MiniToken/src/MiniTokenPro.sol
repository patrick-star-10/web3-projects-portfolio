// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice 更工程化的 ERC20：更完整的校验、常见扩展点、事件更标准、可配置owner、approve安全用法
contract MiniTokenPro {
   
    string public name; // 代币名称
    string public symbol;// 代币符号
    uint8 public immutable decimals;// 小数位数

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;// 地址余额映射
    mapping(address => mapping(address => uint256)) public allowance;// 授权额度映射

   
    address public owner;// 合约所有者

    
    // ERC20标准事件
    event Transfer(address indexed from, address indexed to, uint256 value);// 转账事件
    event Approval(address indexed owner, address indexed spender, uint256 value);// 授权事件
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);// 所有权转移

    
    error ZeroAddress();// 地址不能为0
    error InsufficientBalance();// 余额不足
    error InsufficientAllowance();// 授权额度不足
    error NotOwner(); // 非owner调用
    error InvalidAmount(); // value为0 / 或超出逻辑（项目可选）
    error ApproveFromNonZeroToNonZero(); // 防止approve经典竞态（可选策略）

    // 权限控制
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

   
    /// @notice 支持部署时指定 owner（工程上常用于工厂部署 / 多签接管）
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _owner
    ) {
        if (_owner == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = _owner;// 设置初始owner

        emit OwnershipTransferred(address(0), _owner);
    }

    // External

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);// 调用内部转账函数
        return true;
    }

    /// @notice 更安全的 approve 策略（两种选一）：
    /// 1) 允许任意改：兼容性最好，但有经典“竞态风险”
    /// 2) 要求从非0改为非0必须先置0：安全更强，但有些前端不兼容
    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);// 调用内部授权函数
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        _spendAllowance(from, msg.sender, value);//确认：msg.sender 是否被 from 授权，并且额度足够
        _transfer(from, to, value); // 调用内部转账函数
        return true;
    }

    /// @notice 工程常用：increaseAllowance / decreaseAllowance
    /// 目的：避免“从旧值直接改新值”的竞态窗口
    function increaseAllowance(address spender, uint256 added) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + added;
        _approve(msg.sender, spender, newAllowance);// 重新设置授权额度
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtracted) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 current = allowance[msg.sender][spender];
        if (current < subtracted) revert InsufficientAllowance();
        _approve(msg.sender, spender, current - subtracted);
        return true;
    }

    // ================= Mint / Burn (Owner) =================

    function mint(address to, uint256 value) external onlyOwner {
        _mint(to, value);
    }

    /// @notice 工程上更常见：burn只允许 burn 自己（或者 burnFrom）
    /// 你原来的 burn(from) 只有owner能烧任何人，这在很多项目里会引发信任风险。
    function burn(uint256 value) external {
        _burn(msg.sender, value);
    }

    /// @notice 如果你确实要“燃烧他人资产”，更标准的是 burnFrom：
    /// 需要先得到对方 allowance 授权（而不是 owner 随便烧）
    function burnFrom(address from, uint256 value) external {
        _spendAllowance(from, msg.sender, value);
        _burn(from, value);
    }

    // ================= Ownership =================

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice 工程常见：放弃所有权（如果你想做“去中心化/不可再mint”）
    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    // ================= Internal Core =================

    function _transfer(address from, address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        // 工程上一般允许 value=0（ERC20标准允许），这里不强制 InvalidAmount
        if (balanceOf[from] < value) revert InsufficientBalance();

        // hooks：工程扩展点（手续费、黑名单、白名单、快照等都从这里插）
        _beforeTokenTransfer(from, to, value);

        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);

        _afterTokenTransfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();

        _beforeTokenTransfer(address(0), to, value);

        totalSupply += value;
        balanceOf[to] += value;

        emit Transfer(address(0), to, value);

        _afterTokenTransfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        if (from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < value) revert InsufficientBalance();

        _beforeTokenTransfer(from, address(0), value);

        balanceOf[from] -= value;
        totalSupply -= value;

        emit Transfer(from, address(0), value);

        _afterTokenTransfer(from, address(0), value);
    }

    function _approve(address _owner, address spender, uint256 value) internal {
        if (_owner == address(0) || spender == address(0)) revert ZeroAddress(); 

        // ✅ 可选安全策略：强制从非0到非0必须先归零（你可按项目需求开关）
        // if (allowance[_owner][spender] != 0 && value != 0) revert ApproveFromNonZeroToNonZero();

        allowance[_owner][spender] = value;
        emit Approval(_owner, spender, value);
    }

    /// @notice 把 allowance 消耗逻辑抽出来，避免 transferFrom/burnFrom 重复写
    function _spendAllowance(address from, address spender, uint256 value) internal {
        uint256 allowed = allowance[from][spender];
        if (allowed < value) revert InsufficientAllowance();

        // 无限授权优化：allowed == max 不扣
        if (allowed != type(uint256).max) {
            allowance[from][spender] = allowed - value;
            emit Approval(from, spender, allowance[from][spender]); // 更符合常见实现
        }
    }

    // ================= Hooks (Extension Points) =================
    /// @notice 你未来加“手续费/黑名单/白名单/反鲸鱼限制/快照/投票”等，都从hook做
    function _beforeTokenTransfer(address from, address to, uint256 value) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 value) internal virtual {}
}