// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/MiniTokenPro.sol";

contract MiniTokenProTest is Test {
    MiniTokenPro token;

    address owner = address(0xA11CE);
    address alice = address(0xB0B);
    address bob   = address(0xCAFE);
    address spender = address(0xAA1A);

    function setUp() public {
        token = new MiniTokenPro("MiniTokenPro", "MTP", 18, owner);// 按照构造函数设置Token参数
    }

    // ---------------- Constructor / Ownership ----------------

    // 测试Token基本信息
    function testConstructorSetsMetadataAndOwner() public view {
        assertEq(token.name(), "MiniTokenPro");
        assertEq(token.symbol(), "MTP");
        assertEq(token.decimals(), 18);
        assertEq(token.owner(), owner);
    }

    //测试部署地址不能为零地址
    function testConstructorRevertsZeroOwner() public {
        vm.expectRevert(MiniTokenPro.ZeroAddress.selector);// 函数选择器将的作用是精准匹配报错
        new MiniTokenPro("X", "X", 18, address(0));
    }

    // 测试Token管理员转移函数
    function testTransferOwnershipOnlyOwner() public {
        vm.expectRevert(MiniTokenPro.NotOwner.selector);
        token.transferOwnership(alice);

        vm.prank(owner);
        token.transferOwnership(alice);
        assertEq(token.owner(), alice);
    }

    // 测试放弃管理员函数
    function testRenounceOwnership() public {
        vm.prank(owner);
        token.renounceOwnership();
        assertEq(token.owner(), address(0));
    }

    // ---------------- Events: Approval / OwnershipTransferred ----------------

    // 测试Approval事件
    function testEmitApprovalOnApprove() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit MiniTokenPro.Approval(alice, spender, 123);
        token.approve(spender, 123);
    }

    // 测试 授权被消耗时，链上可观测状态是否正确更新
    function testEmitApprovalOnTransferFromAllowanceSpend() public {
        // 先给 alice 铸币
        vm.prank(owner);
        token.mint(alice, 100);

        // alice 授权 spender 50
        vm.prank(alice);
        token.approve(spender, 50);

        // spender 用掉 20：应当触发 Approval(from, spender, newAllowance=30)
        vm.prank(spender);

        vm.expectEmit(true, true, true, true);
        emit MiniTokenPro.Approval(alice, spender, 30);

        token.transferFrom(alice, bob, 20);
    }

    //当 allowance 是“无限授权时，transferFrom 不应该扣额度，也不应该 emit Approval 事件。
    function testNoApprovalEventWhenInfiniteAllowanceTransferFrom() public {
        // 先给 alice 铸币
        vm.prank(owner);
        token.mint(alice, 100);

        // alice 给 spender 无限授权
        vm.prank(alice);
        token.approve(spender, type(uint256).max);

        // 关键点：你的实现里 infinite allowance 不扣，不 emit Approval
        // 所以这里我们用 recordLogs 来验证“没有 Approval 事件”
        vm.recordLogs();//记录所有 emit 的事件日志

        vm.prank(spender);
        token.transferFrom(alice, bob, 1);

        Vm.Log[] memory logs = vm.getRecordedLogs(); //取回所有日志，类型是哈希数组和原始类型数据

        // 遍历日志，确保没有 Approval 事件 topic
        bytes32 approvalSig = keccak256("Approval(address,address,uint256)"); //把事件类型 转成一个唯一的哈希指纹
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == approvalSig) {// 检测是否有Approval事件
                fail("Unexpected Approval event for infinite allowance");// 一旦检测到Approval事件即可报错
            }
        }
    }

    // 检测权限转移日志事件记录
    function testEmitOwnershipTransferredOnTransferOwnership() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit MiniTokenPro.OwnershipTransferred(owner, alice);
        token.transferOwnership(alice);
    }

    // 检测放弃管理员日志记录
    function testEmitOwnershipTransferredOnRenounceOwnership() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit MiniTokenPro.OwnershipTransferred(owner, address(0));

        token.renounceOwnership();
    }

        

    // ---------------- Mint / Burn ----------------

    // 检测是否只有管理员才能铸币
    function testMintOnlyOwner() public {
        vm.expectRevert(MiniTokenPro.NotOwner.selector);
        token.mint(alice, 100);
        vm.prank(owner);
        token.mint(alice, 100);
        assertEq(token.totalSupply(), 100);
        assertEq(token.balanceOf(alice), 100);
    }

    // 不能往零地址铸币
    function testMintRevertsZeroTo() public {
        vm.prank(owner);
        vm.expectRevert(MiniTokenPro.ZeroAddress.selector);
        token.mint(address(0), 1);
    }

    // 检测是否能自我销毁token
    function testBurnSelf() public {
        vm.prank(owner);
        token.mint(alice, 100);
        vm.prank(alice);
        token.burn(40);
        assertEq(token.balanceOf(alice), 60);
        assertEq(token.totalSupply(), 60);
    }

    //  检测烧毁时余额不足是否报错
    function testBurnRevertsInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(MiniTokenPro.InsufficientBalance.selector);
        token.burn(1);
    }

    // 检测授权燃烧token
    function testBurnFromConsumesAllowance() public {
        vm.prank(owner);
        token.mint(alice, 100);

        // alice approves spender for 30
        vm.prank(alice);
        token.approve(spender, 30);

        // spender burns 20 from alice
        vm.prank(spender);
        token.burnFrom(alice, 20);

        assertEq(token.balanceOf(alice), 80);
        assertEq(token.totalSupply(), 80);
        assertEq(token.allowance(alice, spender), 10);
    }

    // 检测烧毁时授权余额是否足够
    function testBurnFromRevertsIfAllowanceInsufficient() public {
        vm.prank(owner);
        token.mint(alice, 100);

        vm.prank(alice);
        token.approve(spender, 5);

        vm.prank(spender);
        vm.expectRevert(MiniTokenPro.InsufficientAllowance.selector);
        token.burnFrom(alice, 6);
    }

    // ---------------- transfer / approve / transferFrom ----------------

    // 测试转账功能
    function testTransfer() public {
        vm.prank(owner);
        token.mint(alice, 100);

        vm.prank(alice);
        token.transfer(bob, 30);

        assertEq(token.balanceOf(alice), 70);
        assertEq(token.balanceOf(bob), 30);
        assertEq(token.totalSupply(), 100);
    }

    // 不能往0地址转账
    function testTransferRevertsZeroTo() public {
        vm.prank(owner);
        token.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert(MiniTokenPro.ZeroAddress.selector);
        token.transfer(address(0), 1);
    }

    // 检测转账时余额不足是否报错
    function testTransferRevertsInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(MiniTokenPro.InsufficientBalance.selector);
        token.transfer(bob, 1);
    }

    // 不能给0地址授权
    function testApproveRevertsZeroSpender() public {
        vm.prank(alice);
        vm.expectRevert(MiniTokenPro.ZeroAddress.selector);
        token.approve(address(0), 1);
    }

    // 检测代转账时授权余额是否会消耗
    function testTransferFromConsumesAllowance() public {
        vm.prank(owner);
        token.mint(alice, 100);

        vm.prank(alice);
        token.approve(spender, 50);

        vm.prank(spender);
        token.transferFrom(alice, bob, 20);

        assertEq(token.balanceOf(alice), 80);
        assertEq(token.balanceOf(bob), 20);
        assertEq(token.allowance(alice, spender), 30);
    }

    // 检测代转账余额不足时是否报错
    function testTransferFromRevertsIfAllowanceInsufficient() public {
        vm.prank(owner);
        token.mint(alice, 100);

        vm.prank(alice);
        token.approve(spender, 10);

        vm.prank(spender);
        vm.expectRevert(MiniTokenPro.InsufficientAllowance.selector);
        token.transferFrom(alice, bob, 11);
    }

    // 检测无限授权时 授权余额不能消耗
    function testInfiniteAllowanceNotDecremented() public {
        vm.prank(owner);
        token.mint(alice, 100);

        vm.prank(alice);
        token.approve(spender, type(uint256).max);

        vm.prank(spender);
        token.transferFrom(alice, bob, 10);

        assertEq(token.allowance(alice, spender), type(uint256).max);
        assertEq(token.balanceOf(bob), 10);
    }

    // ---------------- increase / decreaseAllowance ----------------

    // 检测增加授权余额
    function testIncreaseAllowance() public {
        vm.prank(alice);
        token.increaseAllowance(spender, 7);
        assertEq(token.allowance(alice, spender), 7);

        vm.prank(alice);
        token.increaseAllowance(spender, 3);
        assertEq(token.allowance(alice, spender), 10);
    }

    // 检测削减授权余额
    function testDecreaseAllowance() public {
        vm.prank(alice);
        token.approve(spender, 10);

        vm.prank(alice);
        token.decreaseAllowance(spender, 4);
        assertEq(token.allowance(alice, spender), 6);
    }

    // 削减授权余额时，削减余额大于已有授权余额时，检测是否报错
    function testDecreaseAllowanceRevertsIfUnderflow() public {
        vm.prank(alice);
        token.approve(spender, 3);

        vm.prank(alice);
        vm.expectRevert(MiniTokenPro.InsufficientAllowance.selector);
        token.decreaseAllowance(spender, 4);
    }

    // 不能往0地址增加或者减少授权余额
    function testIncreaseDecreaseRevertZeroSpender() public {
        vm.prank(alice);
        vm.expectRevert(MiniTokenPro.ZeroAddress.selector);
        token.increaseAllowance(address(0), 1);

        vm.prank(alice);
        vm.expectRevert(MiniTokenPro.ZeroAddress.selector);
        token.decreaseAllowance(address(0), 1);
    }

    // ---------------- Events (示例：验证 Transfer 事件) ----------------

    // 检测是否记录转账事件
    function testEmitTransferOnTransfer() public {
        vm.prank(owner);
        token.mint(alice, 100);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit MiniTokenPro.Transfer(alice, bob, 1);
        token.transfer(bob, 1);
    }
}