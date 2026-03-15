// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

error ZeroAddress();
error TokenNotExist(uint256 tokenId);
error TokenAlreadyMinted(uint256 tokenId);

error NotOwnerNorApproved();
error ApprovalToCurrentOwner();
error ApproveCallerNotOwnerNorOperator();
error ApproveToCaller();

error TransferToZeroAddress();
error TransferFromIncorrectOwner();

error ERC721InvalidReceiver(address receiver);