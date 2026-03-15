// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValueVault} from "../src/ValueVault.sol";

/// @dev 本测试仅使用到的 Foundry Cheatcode 子集。
interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract ValueVaultTest {
    /// @dev Foundry 约定的 cheatcode 地址。
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ValueVault private vault;

    function setUp() public {
        vault = new ValueVault();
    }

    function testInitialValueIsZero() public view {
        require(vault.getValue() == 0, "initial value should be 0");
    }

    function testSetValueUpdatesStoredValue() public {
        uint256 newValue = 42;
        vault.setValue(newValue);

        require(vault.getValue() == newValue, "stored value mismatch");
    }

    function testSetValueEmitsValueChangedEvent() public {
        uint256 newValue = 7;

        // 记录并回放日志，校验事件签名与 payload 是否正确。
        vm.recordLogs();
        vault.setValue(newValue);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        require(logs.length == 1, "expected one log");
        require(logs[0].emitter == address(vault), "unexpected emitter");
        require(logs[0].topics.length == 1, "unexpected topics length");
        require(logs[0].topics[0] == keccak256("ValueChanged(uint256)"), "event signature mismatch");
        require(abi.decode(logs[0].data, (uint256)) == newValue, "event value mismatch");
    }

    function testFuzzSetValue(uint256 newValue) public {
        vault.setValue(newValue);

        require(vault.getValue() == newValue, "fuzz stored value mismatch");
    }
}
