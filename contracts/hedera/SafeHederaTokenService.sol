// SPDX-License-Identifier: Apache-2.0
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "./HederaTokenService.sol";
import '../libraries/SafeCast.sol';
import "./IHederaTokenService.sol";

contract SafeHederaTokenService is HederaTokenService {

    using SafeCast for uint256;

    event Transfer(address indexed from, address indexed to, uint64 value);
    event Approve(address indexed spender, uint64 value);

    function safeMintToken(address token, address to, uint256 amount, bytes[] memory metadata) internal
    returns (uint64 newTotalSupply, int64[] memory serialNumbers) {
        int responseCode;
        (responseCode, newTotalSupply, serialNumbers) = HederaTokenService.mintToken(token, amount.toUint64(), metadata);
        require(responseCode == HederaResponseCodes.SUCCESS, "Safe mint failed!");
        emit Transfer(address(0), to, amount.toUint64());
    }

    function safeBurnToken(address token, address to, uint256 amount, int64[] memory serialNumbers) internal
    returns (uint64 newTotalSupply)
    {
        int responseCode;
        (responseCode, newTotalSupply) = HederaTokenService.burnToken(token, amount.toUint64(), serialNumbers);
        require(responseCode == HederaResponseCodes.SUCCESS, "Safe burn failed!");
        emit Transfer(to, address(0), amount.toUint64());
    }

    function safeAssociateTokens(address account, address[] memory tokens) internal {
        int responseCode;
        responseCode = HederaTokenService.associateTokens(account, tokens);
        require(responseCode == HederaResponseCodes.SUCCESS, "Safe multiple associations failed!");
    }

    function safeAssociateToken(address account, address token) internal {
        int responseCode;
        responseCode = HederaTokenService.associateToken(account, token);
        require(responseCode == HederaResponseCodes.SUCCESS, "Safe single association failed!");
    }

    function safeTransferToken(address token, address sender, address receiver, uint256 amount) internal {
        int responseCode;
        responseCode = HederaTokenService.transferToken(token, sender, receiver, amount.toInt64());
        require(responseCode == HederaResponseCodes.SUCCESS, "Safe token transfer failed!");
        emit Transfer(sender, receiver, uint64(amount));
    }

    function safeApproveToken(address token, address spender, uint256 amount) internal {
        int responseCode;
        responseCode = HederaTokenService.approve(token, spender, amount.toInt64());
        require(responseCode == HederaResponseCodes.SUCCESS, "Safe approve failed!");
        emit Approve(spender, uint64(amount));
    }

    function safeDissociateToken(address account, address token) internal {
        int responseCode;
        responseCode = HederaTokenService.dissociateToken(account, token);
        require(responseCode == HederaResponseCodes.SUCCESS, "Safe single association failed!");
    }
}
