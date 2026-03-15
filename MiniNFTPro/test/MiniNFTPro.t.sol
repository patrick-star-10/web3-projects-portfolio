// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/MiniNFTPro.sol";
import "../src/interfaces/IERC721Receiver.sol";
import "../src/utils/Errors.sol";

// 模拟一个正确实现了 IERC721Receiver 接口的合约，给测试合约提供测试环境
contract ERC721ReceiverOk is IERC721Receiver {
    // 记录最后一次接收 token 的操作信息，方便测试验证
    address public lastOperator;
    address public lastFrom;
    uint256 public lastTokenId;
    bytes public lastData;
    // 实现 onERC721Received 接口，记录参数并返回正确的 selector 表示成功接收
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        lastOperator = operator;
        lastFrom = from;
        lastTokenId = tokenId;
        lastData = data;
        return IERC721Receiver.onERC721Received.selector;
    }
}
// 模拟一个实现了 IERC721Receiver 接口但返回错误 selector 的合约，用于测试接收方检查失败的情况
contract ERC721ReceiverBadSelector is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return bytes4(0);// 返回错误的 selector，表示接收失败
    }
}
// 模拟一个实现了 IERC721Receiver 接口但在 onERC721Received 中 revert 的合约，用于测试接收方检查失败的情况
contract ERC721ReceiverRevertReason is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        revert("RECEIVER_REVERTED");//带原因的 revert
    }
}
// 模拟一个实现了 IERC721Receiver 接口但在 onERC721Received 中 revert 且没有返回错误信息的合约，用于测试接收方检查失败的情况
contract ERC721ReceiverRevertNoReason is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        revert();// 不带原因的 revert
    }
}

contract MiniNFTProTest is Test {
    MiniNFTPro internal nft;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA11);
    address internal operator = address(0x0F3);

    // 每个测试函数运行前都会调用 setUp()，在这里我们部署一个新的 MiniNFTPro 合约实例，确保每个测试都是独立的
    function setUp() public {
        nft = new MiniNFTPro("Mini NFT Pro", "MNFTP", "https://meta.example/token/");
    }
    // 测试构造函数是否正确设置了合约的 name、symbol、baseURI 和 owner
    function test_constructorMetadataAndOwner() public view {
        assertEq(nft.name(), "Mini NFT Pro");
        assertEq(nft.symbol(), "MNFTP");
        assertEq(nft.baseURI(), "https://meta.example/token/");
        assertEq(nft.owner(), address(this));
    }
    // 测试 supportsInterface 函数是否正确报告了合约支持的接口
    function test_supportsInterface() public view {
        assertTrue(nft.supportsInterface(type(IERC165).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC721).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC721Metadata).interfaceId));
        assertFalse(nft.supportsInterface(0xffffffff));
    }
    // 测试 mint 函数只能被合约 owner 调用，其他地址调用会 revert
    function test_mint_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(bytes("not owner"));
        nft.mint(alice, 1);// alice 不是 owner，调用 mint 应该 revert
    }
    // 测试 mint 函数成功铸造一个 tokenId 给指定地址，并且 ownerOf 和 balanceOf 返回正确的结果
    function test_mint_success() public {
        nft.mint(alice, 1);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
    }
    // 测试 mint 函数不能铸造给零地址，应该 revert
    function test_mint_revertZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        nft.mint(address(0), 1);
    }
    // 测试 mint 函数不能铸造已经存在的 tokenId，应该 revert
    function test_mint_revertDuplicateTokenId() public {
        nft.mint(alice, 1);
        vm.expectRevert(abi.encodeWithSelector(TokenAlreadyMinted.selector, 1));
        nft.mint(bob, 1);
    }
    // 测试 setBaseURI 函数只能被 owner 调用，其他地址调用会 revert
    function test_setBaseURI_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(bytes("not owner"));
        nft.setBaseURI("https://evil.example/");
    }
    // 测试 setBaseURI 函数成功更新 baseURI，并且 tokenURI 返回正确的结果
    function test_setBaseURI_success() public {
        nft.setBaseURI("https://new.example/");
        nft.mint(alice, 7);
        assertEq(nft.baseURI(), "https://new.example/");
        assertEq(nft.tokenURI(7), "https://new.example/7");
    }
    // 测试 tokenURI 函数对于不存在的 tokenId 应该 revert，并且返回正确的错误信息
    function test_tokenURI_revertForNonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(TokenNotExist.selector, 99));
        nft.tokenURI(99);
    }
    // 测试 tokenURI 函数当 baseURI 为空时应该返回空字符串
    function test_tokenURI_emptyWhenBaseEmpty() public {
        nft.setBaseURI("");
        nft.mint(alice, 5);
        assertEq(nft.tokenURI(5), "");
    }
    // 测试 approve 函数成功授权一个地址操作指定 tokenId，并且 getApproved 返回正确的结果
    function test_approveAndGetApproved() public {
        nft.mint(alice, 1);
        vm.prank(alice);
        nft.approve(bob, 1);
        assertEq(nft.getApproved(1), bob);
    }
    // 测试 approve 函数不能授权给当前 tokenId 的 owner，应该 revert
    function test_approve_revertToCurrentOwner() public {
        nft.mint(alice, 1);
        vm.prank(alice);
        vm.expectRevert(ApprovalToCurrentOwner.selector);
        nft.approve(alice, 1);
    }
    // 测试 approve 函数不能被非 owner 或者已授权的 operator 调用，应该 revert
    function test_approve_revertCallerNotOwnerNorOperator() public {
        nft.mint(alice, 1);
        vm.prank(bob);
        vm.expectRevert(ApproveCallerNotOwnerNorOperator.selector);
        nft.approve(carol, 1);
    }
    // 测试 approve 函数不能授权给自己，应该 revert
    function test_setApprovalForAll_andSelfApproveRevert() public {
        vm.prank(alice);
        vm.expectRevert(ApproveToCaller.selector);
        nft.setApprovalForAll(alice, true);// alice 不能把自己设置为 operator，应该 revert

        vm.prank(alice);
        nft.setApprovalForAll(operator, true);
        assertTrue(nft.isApprovedForAll(alice, operator));// operator 是 alice 的 operator，应该成功设置
    }
    // 测试 transferFrom 函数只能被 owner 或者已授权的地址调用，其他地址调用会 revert
    function test_transferFrom_byApproved() public {
        nft.mint(alice, 1);
        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(bob);
        nft.transferFrom(alice, carol, 1);

        assertEq(nft.ownerOf(1), carol);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(carol), 1);
        assertEq(nft.getApproved(1), address(0));// 转移后授权应该被清空
    }
    // 测试 transferFrom 函数不能转移给零地址，应该 revert
    function test_transferFrom_revertPaths() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert(TransferToZeroAddress.selector);// 转移给零地址应该 revert
        nft.transferFrom(alice, address(0), 1);

        vm.prank(alice);
        vm.expectRevert(TransferFromIncorrectOwner.selector);// 从错误的 owner 转移应该 revert
        nft.transferFrom(bob, carol, 1);

        vm.prank(bob);
        vm.expectRevert(NotOwnerNorApproved.selector);// bob 既不是 owner 也没有被授权，调用 transferFrom 应该 revert
        nft.transferFrom(alice, carol, 1);
    }
    // 测试 safeTransferFrom 函数的重载版本能够正确调用，并且当接收方是合约时会调用 onERC721Received 进行检查
    function test_safeTransferFrom_overloadAndReceiverCheck() public {
        nft.mint(alice, 1);
        ERC721ReceiverOk recv = new ERC721ReceiverOk();

        vm.prank(alice);
        nft.safeTransferFrom(alice, address(recv), 1);// 使用不带 data 的 safeTransferFrom

        assertEq(nft.ownerOf(1), address(recv));
        assertEq(recv.lastOperator(), alice);
        assertEq(recv.lastFrom(), alice);
        assertEq(recv.lastTokenId(), 1);
        assertEq(recv.lastData().length, 0);
    }
    // 测试 safeTransferFrom 函数能够正确传递 data 参数，并且接收方能够正确接收
    function test_safeTransferFrom_withData() public {
        nft.mint(alice, 1);
        ERC721ReceiverOk recv = new ERC721ReceiverOk();
        bytes memory data = hex"1234";

        vm.prank(alice);
        nft.safeTransferFrom(alice, address(recv), 1, data);

        assertEq(recv.lastData(), data);
    }
    // 测试 safeTransferFrom 函数当接收方没有正确实现 onERC721Received 接口时会 revert，并且状态会回滚
    function test_safeTransferFrom_revertInvalidReceiverAndStateRollback() public {
        nft.mint(alice, 1);
        ERC721ReceiverBadSelector bad = new ERC721ReceiverBadSelector();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(bad)));// 接收方返回错误的 selector 应该 revert，并且 revert 的错误信息应该包含接收方地址
        nft.safeTransferFrom(alice, address(bad), 1);// 转移应该失败，状态应该回滚

        assertEq(nft.ownerOf(1), alice);// 转移失败，owner 应该还是 alice
    }
    // 测试 safeMint 函数能够正确调用 _safeMint，并且当接收方是合约时会调用 onERC721Received 进行检查
    function test_safeMint_receiverChecks() public {
        ERC721ReceiverOk ok = new ERC721ReceiverOk();
        nft.safeMint(address(ok), 2, hex"beef");

        assertEq(nft.ownerOf(2), address(ok));
        assertEq(ok.lastOperator(), address(this));
        assertEq(ok.lastFrom(), address(0));
        assertEq(ok.lastTokenId(), 2);
        assertEq(ok.lastData(), hex"beef");
    }
    // 测试 safeMint 函数当接收方没有正确实现 onERC721Received 接口时会 revert，并且状态会回滚
    function test_safeMint_revertBadSelector() public {
        ERC721ReceiverBadSelector bad = new ERC721ReceiverBadSelector();
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(bad)));
        nft.safeMint(address(bad), 3, "");
    }
    // 测试 safeMint 函数当接收方在 onERC721Received 中 revert 时会正确复用 revert 的原因，并且状态会回滚
    function test_safeMint_bubblesReceiverReason() public {
        ERC721ReceiverRevertReason bad = new ERC721ReceiverRevertReason();
        vm.expectRevert(bytes("RECEIVER_REVERTED"));// 接收方带原因的 revert 应该被正确复用，转移失败
        nft.safeMint(address(bad), 4, "");// 转移应该失败，状态应该回滚
    }
    // 测试 safeMint 函数当接收方在 onERC721Received 中 revert 且没有返回错误信息时会正确复用 revert，并且状态会回滚
    function test_safeMint_revertNoReasonAsInvalidReceiver() public {
        ERC721ReceiverRevertNoReason bad = new ERC721ReceiverRevertNoReason();
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(bad)));
        nft.safeMint(address(bad), 5, "");
    }
    // 测试 burn 函数只能被 owner 或者已授权的地址调用，其他地址调用会 revert，并且成功燃烧后 tokenId 不再存在
    function test_burn_byOwnerApprovedOrOperator() public {
        nft.mint(alice, 1);
        vm.prank(alice);
        nft.burn(1);
        vm.expectRevert(abi.encodeWithSelector(TokenNotExist.selector, 1));
        nft.ownerOf(1);

        nft.mint(alice, 2);
        vm.prank(alice);
        nft.approve(bob, 2);
        vm.prank(bob);
        nft.burn(2);
        vm.expectRevert(abi.encodeWithSelector(TokenNotExist.selector, 2));
        nft.ownerOf(2);

        nft.mint(alice, 3);
        vm.prank(alice);
        nft.setApprovalForAll(operator, true);
        vm.prank(operator);
        nft.burn(3);
        vm.expectRevert(abi.encodeWithSelector(TokenNotExist.selector, 3));
        nft.ownerOf(3);
    }
    // 测试 burn 函数不能被非 owner 或者未授权的地址调用，应该 revert
    function test_burn_revertNotAuthorized() public {
        nft.mint(alice, 1);
        vm.prank(bob);
        vm.expectRevert(NotOwnerNorApproved.selector);
        nft.burn(1);
    }
    // 测试授权不存在的 tokenId 应该 revert，并且返回正确的错误信息
    function test_getApproved_revertNonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(TokenNotExist.selector, 42));// 获取不存在的 tokenId 的授权应该 revert，并且错误信息应该包含 tokenId
        nft.getApproved(42);
    }
    // 测试 balanceOf 函数对于零地址应该 revert，并且返回正确的错误信息
    function test_balanceOf_zeroAddressRevert() public {
        vm.expectRevert(ZeroAddress.selector);
        nft.balanceOf(address(0));
    }
    // 测试 transferOwnership 函数成功转移合约所有权，并且新的 owner 能够调用 owner-only 的函数，旧的 owner 不能再调用 owner-only 的函数
    function test_transferOwnership_changesMintAuthority() public {
        nft.transferOwnership(alice);

        vm.expectRevert(bytes("not owner"));
        nft.mint(bob, 10);

        vm.prank(alice);
        nft.mint(bob, 10);
        assertEq(nft.ownerOf(10), bob);
    }
}
