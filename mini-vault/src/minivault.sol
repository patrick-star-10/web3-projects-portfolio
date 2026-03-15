// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title MiniVault - ETH 小金库（极简版）
contract MiniVault {
    // 管理员（部署合约的人）
    address public owner;

    // 是否暂停
    bool public paused;

    // 每个地址在本合约里的余额
    mapping(address => uint256) private balances;

    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Paused(bool paused);

    constructor() {
        owner = msg.sender;
    }

    // 修饰器：未暂停
    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    // 存 ETH
    function deposit() external payable whenNotPaused {
        require(msg.value > 0, "no eth");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // 查余额
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    // 取 ETH
    function withdraw(uint256 amount) external whenNotPaused {
        require(amount > 0, "amount=0");
        require(balances[msg.sender] >= amount, "not enough");

        balances[msg.sender] -= amount;

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    // 管理员暂停 / 恢复
    function setPaused(bool _paused) external {
        require(msg.sender == owner, "not owner");
        paused = _paused;
        emit Paused(_paused);
    }

    // 合约总余额
    function totalBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // 拒收直接转账
    receive() external payable {
        revert("use deposit");
    }
}