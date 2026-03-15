// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/minivault.sol"; 

contract MinivaultTest is Test {
    // ⚠️ 这里的合约名必须和你 src/minivault.sol 里 contract 名字完全一致
    MiniVault vault;

    address alice = address(0x1);
    address bob   = address(0x2);
    address carol = address(0x3);

    // 每次执行test前，都会先执行 setUp
    function setUp() public {
        vault = new MiniVault();

        // 给测试账户打钱（假 ETH）
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
    }

    // ========== 基础：deposit ==========

    function testDeposit() public {
        vm.prank(alice);//伪装下一次外部调用的 msg.sender 为 alice
        vault.deposit{value: 1 ether}();//往Alice的账户存1ETH

        assertEq(vault.balanceOf(alice), 1 ether);//断言 Alice的余额是1ETH
        assertEq(vault.totalBalance(), 1 ether);// 断言 合约总余额是1ETH
    }

    function testDepositRevertWhenZeroValue() public {
        vm.prank(alice);
        vm.expectRevert(bytes("no eth"));//监听revert，要求revert 的字符串和合约里require 的字符串一致
        vault.deposit{value: 0}();
    }

    // ========== 基础：withdraw ==========

    function testWithdraw() public {
        // Alice 存 2 ETH
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        // Alice 取 1 ETH
        vm.prank(alice);
        vault.withdraw(1 ether);

        // 余额应变为 1 ETH
        assertEq(vault.balanceOf(alice), 1 ether);
        assertEq(vault.totalBalance(), 1 ether);
    }

    function testWithdrawRevertWhenAmountZero() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(bytes("amount=0")); // 你的合约里 require 的字符串必须一致
        vault.withdraw(0);
    }

    function testWithdrawRevertWhenNotEnough() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(bytes("not enough"));
        vault.withdraw(2 ether);
    }

    // ========== 多账户隔离 ==========

    function testMultiUsersIndependentBalances() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(bob);
        vault.deposit{value: 3 ether}();

        assertEq(vault.balanceOf(alice), 1 ether);
        assertEq(vault.balanceOf(bob), 3 ether);
        assertEq(vault.totalBalance(), 4 ether);
    }

    function testCannotWithdrawOthersBalance() public {
        // Alice 存 2
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        // Bob 试图取 1（Bob 自己没存钱）
        vm.prank(bob);
        vm.expectRevert(bytes("not enough"));
        vault.withdraw(1 ether);
    }

    // ========== 暂停机制 ==========

    function testOnlyOwnerCanPause() public {
        // 非 owner（alice）调用 setPaused 应该失败
        vm.prank(alice);
        vm.expectRevert(bytes("not owner"));
        vault.setPaused(true);
    }

    function testPauseBlocksDepositAndWithdraw() public {
        // 先 Alice 存 1
        vm.prank(alice);
        vault.deposit{value: 1 ether}();//调用后prank失效

        // owner 暂停
        vault.setPaused(true);

        // 暂停后 deposit 应该 revert
        vm.prank(alice);
        vm.expectRevert(bytes("paused"));
        vault.deposit{value: 1 ether}();

        // 暂停后 withdraw 也应该 revert
        vm.prank(alice);
        vm.expectRevert(bytes("paused"));
        vault.withdraw(1 ether);
    }

    function testUnpauseRestoresDepositAndWithdraw() public {
        // owner 暂停
        vault.setPaused(true);

        // owner 解除暂停
        vault.setPaused(false);

        // 现在可以 deposit
        vm.prank(alice);
        vault.deposit{value: 2 ether}();
        assertEq(vault.balanceOf(alice), 2 ether);

        // 现在可以 withdraw
        vm.prank(alice);
        vault.withdraw(1 ether);
        assertEq(vault.balanceOf(alice), 1 ether);
    }

    // ========== receive 拒收直转 ==========

    function testReceiveRevertsDirectEthTransfer() public {
        // 直接给合约地址转 ETH（不走 deposit），应该 revert("use deposit")
        vm.prank(alice);
        vm.expectRevert(bytes("use deposit"));
        (bool ok,) = address(vault).call{value: 1 ether}("");
        // 这一行不会执行到，因为上面 expectRevert 会捕获 revert
        // 但为了完整性：如果没 revert，会导致测试失败
        assertTrue(ok);//兜底断言
    }

    // ========== 事件（可选，但很重要） ==========

    function testEmitDepositEvent() public {
        vm.prank(alice);

        // 期待触发 Deposit(alice, 1 ether)
        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, 1 ether);

        vault.deposit{value: 1 ether}();
    }

    function testEmitWithdrawEvent() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        vm.prank(alice);

        vm.expectEmit(true, false, false, true);
        emit Withdraw(alice, 1 ether);

        vault.withdraw(1 ether);
    }

    // ⚠️ 事件必须在测试合约里声明一份，才能用于 expectEmit + emit
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
}