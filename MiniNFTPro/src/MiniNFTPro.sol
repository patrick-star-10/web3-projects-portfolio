// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./interfaces/IERC721Metadata.sol";
import "./interfaces/IERC721Receiver.sol";
import "./libs/Strings.sol";
import "./utils/Errors.sol";
import "./utils/Ownable.sol";

contract MiniNFTPro is IERC721Metadata, Ownable {
    using Strings for uint256;// 调用string库

    // ===== Metadata =====
    string private _n; //名称
    string private _s; // 符号
    string private _base;// 元数据链接前缀

    // ===== ERC721 Storage =====
    mapping(uint256 => address) private _owners; // tokenId到owner的映射
    mapping(address => uint256) private _balances; // owner 到token数量的映射
    mapping(uint256 => address) private _tokenApprovals; // tokenId到授权地址的映射
    mapping(address => mapping(address => bool)) private _operatorApprovals; // tokenId的批量授权映射

    // 初始化NFT data
    constructor(string memory name_, string memory symbol_, string memory baseURI_) {
        _n = name_;
        _s = symbol_;
        _base = baseURI_;
    }

   
    // IERC165  身份识别
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    // IERC721Metadata
   // 名称查询
    function name() external view override returns (string memory) {
        return _n;
    }
    // 符号查询
    function symbol() external view override returns (string memory) {
        return _s;
    }
    // 元数据链接前缀设置和查询
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _base = newBaseURI;
    }
    // 元数据链接前缀查询
    function baseURI() external view returns (string memory) {
        return _base;
    }

    // baseURI + tokenId（你想加 ".json" 也可以自己改）
    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenNotExist(tokenId);// 不存在的 tokenId 应该 revert
        if (bytes(_base).length == 0) return "";// 如果 baseURI 为空，返回空字符串
        return string(abi.encodePacked(_base, tokenId.toString()));// 连接 baseURI 和 tokenId 生成完整的 tokenURI
    }

    // IERC721 view
    // 查询 owner 的 token 数量
    function balanceOf(address owner_) external view override returns (uint256) {
        if (owner_ == address(0)) revert ZeroAddress();// 0地址不合法
        return _balances[owner_];// 返回 owner_ 的 token 数量
    }

    // 查询 tokenId 的 owner
    function ownerOf(uint256 tokenId) public view override returns (address) {
        address o = _owners[tokenId];// 查询 tokenId 的 owner
        if (o == address(0)) revert TokenNotExist(tokenId);// tokenId 不存在应该 revert
        return o;// 返回 tokenId 的 owner
    }

    // 查询 tokenId 的授权地址
    function getApproved(uint256 tokenId) external view override returns (address) {
        if (!_exists(tokenId)) revert TokenNotExist(tokenId);
        return _tokenApprovals[tokenId];// 返回 tokenId 的授权地址
    }

    // 查询 operator 是否被 owner_ 批量授权
    function isApprovedForAll(address owner_, address operator) external view override returns (bool) {
        return _operatorApprovals[owner_][operator];
    }

   
    // Approvals (write)
    // 单 token 授权
    function approve(address to, uint256 tokenId) external override {
        address o = ownerOf(tokenId); // 查询 tokenId 的 owner（顺便验证 tokenId 是否存在）
        if (to == o) revert ApprovalToCurrentOwner();// 不允许给自己授权

        if (msg.sender != o && !_operatorApprovals[o][msg.sender]) {
            revert ApproveCallerNotOwnerNorOperator();// 只有 owner 或者 operator 才能授权
        }

        _approve(o, to, tokenId);
    }

    // 批量授权
    function setApprovalForAll(address operator, bool approved) external override {
        if (operator == msg.sender) revert ApproveToCaller();// 不允许给自己授权
        _operatorApprovals[msg.sender][operator] = approved;// 设置批量授权状态
        emit ApprovalForAll(msg.sender, operator, approved);
    }

   
    // Transfers
    // 授权级别转移
    function transferFrom(address from, address to, uint256 tokenId) external override {
        address o = ownerOf(tokenId);

        if (from != o) revert TransferFromIncorrectOwner();// 转移的 token 必须属于 from
        if (to == address(0)) revert TransferToZeroAddress();// 转移的目标地址不能是 0 地址
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerNorApproved();// 只有 owner 或者被授权的地址才能转移 token

        _transfer(from, to, tokenId);// 执行转移
    }

    // 安全转移（如果 to 是合约，必须实现 IERC721Receiver 接口）
    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        this.safeTransferFrom(from, to, tokenId, "");
    }

    // 安全转移重载
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external override {
        address o = ownerOf(tokenId);

        if (from != o) revert TransferFromIncorrectOwner();
        if (to == address(0)) revert TransferToZeroAddress();
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerNorApproved();

        _safeTransfer(from, to, tokenId, data);
    }

    
    // Mint / Burn (Pro)
    // Pro：mint 只给 owner（后续你可扩 minter role）
    // 铸造 tokenId 给 to 地址
    function mint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId, bytes("")); // 直接调用 _safeMint，确保安全转移检查
    }

    //安全铸造 tokenId 给 to 地址，并附带 data 数据（如果 to 是合约，data 会被传递给 onERC721Received）
    function safeMint(address to, uint256 tokenId, bytes calldata data) external onlyOwner {
        _safeMint(to, tokenId, data);
    }

    // Pro：burn 允许 owner / approved / operator（更贴近真实项目）
    function burn(uint256 tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerNorApproved();// 只有 owner 或者被授权的地址才能销毁 token
        _burn(tokenId);
    }

   
    // Internal Engine
    // 判断 tokenId 是否存在（即是否被铸造过）
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);// 如果 tokenId 的 owner 不为 0 地址，说明 tokenId 存在
    }

    // 判断 spender 是否是 tokenId 的 owner 或者被授权的地址
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address o = _owners[tokenId];
        if (o == address(0)) return false;// tokenId 不存在
        // spender 是 owner 或者被授权的地址，或者是 owner 批量授权的 operator 都可以操作 tokenId
        return (spender == o ||
            _tokenApprovals[tokenId] == spender ||
            _operatorApprovals[o][spender]);
    }

    // 内部函数：设置 tokenId 的授权地址，并触发 Approval 事件
    function _approve(address owner_, address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner_, to, tokenId);
    }

    // 内部函数：执行 tokenId 的转移（不检查授权和安全接收）
    function _transfer(address from, address to, uint256 tokenId) internal {
        _beforeTokenTransfer(from, to, tokenId);

        // 清空单 token 授权（转移后旧授权必须失效）
        _approve(from, address(0), tokenId);
        // 更新 owner 和 balance（使用 unchecked 块节省 gas，前提是我们已经通过 require 检查了边界条件）
        unchecked {
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;// 更新 tokenId 的 owner

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    // 内部函数：执行安全转移，转移后检查 to 是否是合约，如果是合约则调用 onERC721Received
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    // 内部函数：铸造 tokenId 给 to 地址（不检查安全接收）
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddress();
        if (_exists(tokenId)) revert TokenAlreadyMinted(tokenId);

        _beforeTokenTransfer(address(0), to, tokenId);

        _owners[tokenId] = to;
        _balances[to] += 1;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    // 内部函数：安全铸造 tokenId 给 to 地址，并附带 data 数据（如果 to 是合约，data 会被传递给 onERC721Received）
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, data);
    }

    // 内部函数：销毁 tokenId，清空授权，更新 owner 和 balance，并触发 Transfer 事件
    function _burn(uint256 tokenId) internal {
        address o = ownerOf(tokenId);

        _beforeTokenTransfer(o, address(0), tokenId);

        _approve(o, address(0), tokenId);// 清空单 token 授权
        // 更新 owner 和 balance（使用 unchecked 块节省 gas，前提是我们已经通过 require 检查了边界条件）
        unchecked {
            _balances[o] -= 1;
        }
        delete _owners[tokenId];// 删除 tokenId 的 owner，表示 tokenId 不再存在

        emit Transfer(o, address(0), tokenId);

        _afterTokenTransfer(o, address(0), tokenId);
    }

    // 内部函数：检查 to 是否是合约，如果是合约则调用 onERC721Received，并检查返回值是否正确
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) internal {
        if (to.code.length == 0) return;// 读取 to的code长度，如果为 0 说明 to 不是合约，直接返回成功
        // to 是合约，调用 onERC721Received，并检查返回值是否正确
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
            if (retval != IERC721Receiver.onERC721Received.selector) {// 返回值不正确，说明to没有正确实现 onERC721Received 接口
                revert ERC721InvalidReceiver(to);// to 没有正确实现 转移失败
            }
        } catch (bytes memory reason) {// 调用 onERC721Received 失败，可能是 to 没有实现接口，或者接口实现有问题
            if (reason.length == 0) {// 没有返回错误信息，说明 to 没有实现 onERC721Received 接口
                revert ERC721InvalidReceiver(to);// to没有实现 转移失败
            } else {
                assembly ("memory-safe") {// 有返回错误信息，使用 assembly 复用错误信息进行 revert
                    revert(add(32, reason), mload(reason))// reason 的前 32 字节存储了 reason 的长度，后面才是 reason 的内容，所以我们需要跳过前 32 字节
                }
            }
        }
    }

   
    // Hooks (可扩展点)
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}
}