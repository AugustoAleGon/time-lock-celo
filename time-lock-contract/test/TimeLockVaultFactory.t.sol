// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TimeLockVaultFactory.sol";

contract TimeLockVaultFactoryTest is Test {
    TimeLockVaultFactory public factory;
    address public bob = address(0x2);

    function setUp() public {
        factory = new TimeLockVaultFactory(address(0));
        vm.deal(bob, 10 ether);
        vm.deal(address(this), 10 ether);
    }

    receive() external payable {}

    function test_CeloVault_HappyPath() public {
        // Setup: call createVaultCelo sending 1 ether with _unlockTime = block.timestamp + 1 days
        uint256 lockAmount = 1 ether;
        uint256 unlockTime = block.timestamp + 1 days;
        
        uint256 vaultId = factory.createVaultCelo{value: lockAmount}(unlockTime);

        // Verify vault was created correctly
        (address creator, address token, uint256 amount, uint256 vaultUnlockTime, bool withdrawn) = factory.vaults(vaultId);
        assertEq(creator, address(this));
        assertEq(token, address(0)); // CELO is represented as address(0)
        assertEq(amount, lockAmount);
        assertEq(vaultUnlockTime, unlockTime);
        assertEq(withdrawn, false);

        // Advance time: vm.warp(block.timestamp + 1 days + 1)
        uint256 warpTo = block.timestamp + 1 days + 1;
        vm.warp(warpTo);

        // Record balance before withdrawal
        uint256 balanceBefore = address(this).balance;

        // Assert: calling withdraw(vaultId) transfers the 1 ETH back to the creator and marks withdrawn = true
        factory.withdraw(vaultId);

        // Verify withdrawal
        (creator, token, amount, vaultUnlockTime, withdrawn) = factory.vaults(vaultId);
        assertEq(withdrawn, true);

        // Verify received the funds
        uint256 balanceAfter = address(this).balance;
        assertEq(balanceAfter, balanceBefore + lockAmount);
    }

    function test_GasUsage() public {
        uint256 gasBefore = gasleft();
        
        uint256 vaultId = factory.createVaultCelo{value: 1 ether}(block.timestamp + 1 days);
        
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for vault creation", gasUsed);
        
        // Verify gas usage is reasonable (should be under 200k gas)
        assertLt(gasUsed, 200000);
    }

    function test_MultipleVaults() public {
        uint256[] memory vaultIds = new uint256[](3);
        
        // Create 3 vaults
        for (uint256 i = 0; i < 3; i++) {
            vaultIds[i] = factory.createVaultCelo{value: 1 ether}(block.timestamp + 1 days + i);
        }
        
        // Verify all vaults were created
        for (uint256 i = 0; i < 3; i++) {
            (address creator, , , , bool withdrawn) = factory.vaults(vaultIds[i]);
            assertEq(creator, address(this));
            assertEq(withdrawn, false);
        }
        
        // Withdraw from first vault
        vm.warp(block.timestamp + 1 days + 1);
        factory.withdraw(vaultIds[0]);
        
        // Verify only first vault is withdrawn
        (,, , , bool withdrawn0) = factory.vaults(vaultIds[0]);
        (,, , , bool withdrawn1) = factory.vaults(vaultIds[1]);
        assertEq(withdrawn0, true);
        assertEq(withdrawn1, false);
    }
}