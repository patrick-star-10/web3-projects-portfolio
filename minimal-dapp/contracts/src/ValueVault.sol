// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ValueVault {
    /// @dev 合约当前持久化的数值状态。
    uint256 private value;

    /// @notice 当 value 被更新时触发。
    /// @param newValue 最新写入的值。
    event ValueChanged(uint256 newValue);

    /// @notice 读取当前存储值。
    /// @return 当前 value。
    function getValue() external view returns (uint256) {
        return value;
    }

    /// @notice 更新存储值。
    /// @dev 成功写入后会触发 {ValueChanged} 事件。
    /// @param _value 要写入的新值。
    function setValue(uint256 _value) external {
        value = _value;
        emit ValueChanged(_value);
    }
}
