// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./HederaResponseCodes.sol";
import "./IHederaTokenService.sol";
import "./IExchangeRate.sol";

abstract contract HederaTokenService is HederaResponseCodes {

    address internal constant precompileAddress = address(0x167);
    address internal constant exchangeRatePrecompileAddress = address(0x168);

    uint internal constant ADMIN_KEY_TYPE = 1;   
    uint internal constant KYC_KEY_TYPE = 2;
    uint internal constant FREEZE_KEY_TYPE = 4;
    uint internal constant WIPE_KEY_TYPE = 8;
    uint internal constant SUPPLY_KEY_TYPE = 16;
    uint internal constant FEE_SCHEDULE_KEY_TYPE = 32;
    uint internal constant PAUSE_KEY_TYPE = 64;
    
    uint256 internal constant TINY_PARTS_PER_WHOLE = 100_000_000;
    uint32 internal constant DEFAULT_AUTO_RENEW_PERIOD = 7776000;

    modifier nonEmptyExpiry(IHederaTokenService.HederaToken memory token)
    {
        if (token.expiry.second == 0 && token.expiry.autoRenewPeriod == 0) {
            token.expiry.autoRenewPeriod = DEFAULT_AUTO_RENEW_PERIOD;
        }
        _;
    }

    function tinycentsToTinybars(uint256 tinycents) public returns (uint256 tinybars) {
        (bool success, bytes memory result) = exchangeRatePrecompileAddress.call(
            abi.encodeWithSelector(IExchangeRate.tinycentsToTinybars.selector, tinycents));
        require(success, 'TinycentsToTinybars failed!');
        tinybars = abi.decode(result, (uint256));
    }

    function tinybarsToTinycents(uint256 tinybars) internal returns (uint256 tinycents) {
        (bool success, bytes memory result) = exchangeRatePrecompileAddress.call(
            abi.encodeWithSelector(IExchangeRate.tinybarsToTinycents.selector, tinybars));
        require(success, 'TinybarsToTinycents failed!');
        tinycents = abi.decode(result, (uint256));
    }

    modifier costsTinycents(uint256 tinycents) {
        uint256 requiredTinybars = tinycentsToTinybars(tinycents);
        require(msg.value >= requiredTinybars, 'Did not send enough msg.value');
        _;
    }

    function createFungibleToken(
        IHederaTokenService.HederaToken memory token,
        uint initialTotalSupply,
        uint decimals) 
    internal nonEmptyExpiry(token) returns (int responseCode, address tokenAddress) {

        (bool success, bytes memory result) = precompileAddress.call{value: msg.value}(
            abi.encodeWithSelector(IHederaTokenService.createFungibleToken.selector,
            token, initialTotalSupply, decimals));

        (responseCode, tokenAddress) = success ? abi.decode(result, (int32, address)) : (HederaResponseCodes.UNKNOWN, address(0));
    }

    // /// Mints an amount of the token to the defined treasury account
    // /// @param token The token for which to mint tokens. If token does not exist, transaction results in
    // ///              INVALID_TOKEN_ID
    // /// @param amount Applicable to tokens of type FUNGIBLE_COMMON. The amount to mint to the Treasury Account.
    // ///               Amount must be a positive non-zero number represented in the lowest denomination of the
    // ///               token. The new supply must be lower than 2^63.
    // /// @param metadata Applicable to tokens of type NON_FUNGIBLE_UNIQUE. A list of metadata that are being created.
    // ///                 Maximum allowed size of each metadata is 100 bytes
    // /// @return responseCode The response code for the status of the request. SUCCESS is 22.
    // /// @return newTotalSupply The new supply of tokens. For NFTs it is the total count of NFTs
    // /// @return serialNumbers If the token is an NFT the newly generate serial numbers, otherwise empty.
    function mintToken(address token, uint64 amount, bytes[] memory metadata) internal
        returns (int responseCode, uint64 newTotalSupply, int64[] memory serialNumbers)
    {
        (bool success, bytes memory result) = precompileAddress.call(
            abi.encodeWithSelector(IHederaTokenService.mintToken.selector,
            token, amount, metadata));
        (responseCode, newTotalSupply, serialNumbers) =
            success
                ? abi.decode(result, (int32, uint64, int64[]))
                : (HederaResponseCodes.UNKNOWN, 0, new int64[](0));
    }

    /// Burns an amount of the token from the defined treasury account
    /// @param token The token for which to burn tokens. If token does not exist, transaction results in
    ///              INVALID_TOKEN_ID
    /// @param amount  Applicable to tokens of type FUNGIBLE_COMMON. The amount to burn from the Treasury Account.
    ///                Amount must be a positive non-zero number, not bigger than the token balance of the treasury
    ///                account (0; balance], represented in the lowest denomination.
    /// @param serialNumbers Applicable to tokens of type NON_FUNGIBLE_UNIQUE. The list of serial numbers to be burned.
    /// @return responseCode The response code for the status of the request. SUCCESS is 22.
    /// @return newTotalSupply The new supply of tokens. For NFTs it is the total count of NFTs
    function burnToken(address token, uint64 amount, int64[] memory serialNumbers) internal
        returns (int responseCode, uint64 newTotalSupply)
    {
        (bool success, bytes memory result) = precompileAddress.call(
            abi.encodeWithSelector(IHederaTokenService.burnToken.selector,
            token, amount, serialNumbers));
        (responseCode, newTotalSupply) =
            success
                ? abi.decode(result, (int32, uint64))
                : (HederaResponseCodes.UNKNOWN, 0);
    }

    ///  Associates the provided account with the provided tokens. Must be signed by the provided
    ///  Account's key or called from the accounts contract key
    ///  If the provided account is not found, the transaction will resolve to INVALID_ACCOUNT_ID.
    ///  If the provided account has been deleted, the transaction will resolve to ACCOUNT_DELETED.
    ///  If any of the provided tokens is not found, the transaction will resolve to INVALID_TOKEN_REF.
    ///  If any of the provided tokens has been deleted, the transaction will resolve to TOKEN_WAS_DELETED.
    ///  If an association between the provided account and any of the tokens already exists, the
    ///  transaction will resolve to TOKEN_ALREADY_ASSOCIATED_TO_ACCOUNT.
    ///  If the provided account's associations count exceed the constraint of maximum token associations
    ///    per account, the transaction will resolve to TOKENS_PER_ACCOUNT_LIMIT_EXCEEDED.
    ///  On success, associations between the provided account and tokens are made and the account is
    ///    ready to interact with the tokens.
    /// @param account The account to be associated with the provided tokens
    /// @param tokens The tokens to be associated with the provided account. In the case of NON_FUNGIBLE_UNIQUE
    ///               Type, once an account is associated, it can hold any number of NFTs (serial numbers) of that
    ///               token type
    /// @return responseCode The response code for the status of the request. SUCCESS is 22.
    function associateTokens(address account, address[] memory tokens) internal returns (int responseCode) {
        (bool success, bytes memory result) = precompileAddress.call(
            abi.encodeWithSelector(IHederaTokenService.associateTokens.selector,
            account, tokens));
        responseCode = success ? abi.decode(result, (int32)) : HederaResponseCodes.UNKNOWN;
    }

    function associateToken(address account, address token) internal returns (int responseCode) {
        (bool success, bytes memory result) = precompileAddress.call(
            abi.encodeWithSelector(IHederaTokenService.associateToken.selector,
            account, token));
        responseCode = success ? abi.decode(result, (int32)) : HederaResponseCodes.UNKNOWN;
    }

    function dissociateToken(address account, address token) internal returns (int responseCode) {
        (bool success, bytes memory result) = precompileAddress.call(
            abi.encodeWithSelector(IHederaTokenService.dissociateToken.selector,
            account, token));
        responseCode = success ? abi.decode(result, (int32)) : HederaResponseCodes.UNKNOWN;
    }

    /**********************
     * ABI v1 calls       *
     **********************/

    /// Transfers tokens where the calling account/contract is implicitly the first entry in the token transfer list,
    /// where the amount is the value needed to zero balance the transfers. Regular signing rules apply for sending
    /// (positive amount) or receiving (negative amount)
    /// @param token The token to transfer to/from
    /// @param sender The sender for the transaction
    /// @param receiver The receiver of the transaction
    /// @param amount Non-negative value to send. a negative value will result in a failure.
    function transferToken(address token, address sender, address receiver, int64 amount) internal
        returns (int responseCode)
    {
        (bool success, bytes memory result) = precompileAddress.call(
            abi.encodeWithSelector(IHederaTokenService.transferToken.selector,
            token, sender, receiver, amount));
        responseCode = success ? abi.decode(result, (int32)) : HederaResponseCodes.UNKNOWN;
    }

    function approve(address token, address spender, int64 amount) internal returns (int responseCode)
    {
        (bool success, bytes memory result) = precompileAddress.call(
            abi.encodeWithSelector(IHederaTokenService.approve.selector,
            token, spender, amount));
        responseCode = success ? abi.decode(result, (int32)) : HederaResponseCodes.UNKNOWN;
    }
}