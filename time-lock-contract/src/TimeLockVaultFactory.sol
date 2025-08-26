// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract TimeLockVaultFactory {
    /// @notice The deployer (could be used for admin actions)
    address public immutable owner;

    /// @notice Auto-incrementing vault ID
    uint256 private nextVaultId;

    /// @notice A single time-locked vault (CELO or ERC-20)
    struct Vault {
        address creator;
        address token;       // zero = CELO, otherwise ERC-20 contract
        uint256 amount;      // amount of CELO or tokens locked
        uint256 unlockTime;  // timestamp when withdrawal allowed
        bool withdrawn;
    }

    /// @dev vaultId => Vault
    mapping(uint256 => Vault) public vaults;

    /// @dev creator => list of vaultIds
    mapping(address => uint256[]) public userVaults;

    /// @param _owner Optional override (pass zero to use msg.sender)
    constructor(address _owner) {
        owner = _owner == address(0) ? msg.sender : _owner;
    }

    /// @notice Lock CELO until `_unlockTime`
    function createVaultCelo(uint256 _unlockTime)
        external
        payable
        returns (uint256 vaultId)
    {
        require(msg.value > 0, "No CELO sent");
        require(_unlockTime > block.timestamp, "Unlock time must be in future");

        vaultId = _storeVault(msg.sender, address(0), msg.value, _unlockTime);
    }

    /// @notice Lock ERC-20 `token` until `_unlockTime`
    /// @dev caller must `approve` this contract for at least `_amount` first
    function createVaultERC20(address token, uint256 amount, uint256 _unlockTime)
        external
        returns (uint256 vaultId)
    {
        require(amount > 0, "Amount must be >0");
        require(_unlockTime > block.timestamp, "Unlock time must be in future");
        require(token != address(0), "Invalid token address");

        // pull tokens in
        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(ok, "Token transfer failed");

        vaultId = _storeVault(msg.sender, token, amount, _unlockTime);
    }

    /// @dev internal helper to record the vault
    function _storeVault(
        address creator,
        address token,
        uint256 amount,
        uint256 _unlockTime
    ) private returns (uint256 vaultId) {
        vaultId = nextVaultId++;
        vaults[vaultId] = Vault({
            creator:   creator,
            token:     token,
            amount:    amount,
            unlockTime:_unlockTime,
            withdrawn: false
        });
        userVaults[creator].push(vaultId);
    }

    /// @notice Withdraw funds after unlock time
    function withdraw(uint256 vaultId) external {
        Vault storage v = vaults[vaultId];

        require(v.creator != address(0), "Vault does not exist");
        require(msg.sender == v.creator, "Not vault creator");
        require(block.timestamp >= v.unlockTime, "Too early");
        require(!v.withdrawn, "Already withdrawn");

        v.withdrawn = true;
        if (v.token == address(0)) {
            // CELO
            payable(v.creator).transfer(v.amount);
        } else {
            // ERC-20
            bool ok = IERC20(v.token).transfer(v.creator, v.amount);
            require(ok, "Token transfer failed");
        }
    }

    /// @notice Prevent accidental CELO sends
    receive() external payable {
        revert("Use createVaultCelo()");
    }
}