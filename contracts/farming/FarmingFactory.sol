/* SPDX-License-Identifier: UNLICENSED */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SavingFarming.sol";
import "./LockFarming.sol";

contract FarmingFactory is Ownable {
    address[] public lpTokens;
    mapping(address => bool) private _isLpTokenSupported;
    mapping(address => address) private _savingFarmingOf;
    mapping(address => uint8) private _numLockTypesOf;
    mapping(address => mapping(uint8 => address)) private _lockFarmingOf;
    mapping(address => bool) private _operators;

    event NewSavingFarming(address lpToken, address savingFarmingContract);
    event NewLockFarming(
        address lpToken,
        uint256 duration,
        uint8 lockType,
        address lockFarmingContract
    );

    constructor() Ownable() {
        _operators[msg.sender] = true;
    }

    modifier onlyOperator() {
        require(_operators[msg.sender], "Caller is not operator");
        _;
    }

    function checkLpTokenStatus(address lpToken) external view returns (bool) {
        return _isLpTokenSupported[lpToken];
    }

    function getNumSupportedLpTokens() external view returns (uint256) {
        return lpTokens.length;
    }

    function getSavingFarmingContract(address lpToken)
        external
        view
        returns (address)
    {
        return _savingFarmingOf[lpToken];
    }

    function getNumLockTypes(address lpToken) external view returns (uint8) {
        return _numLockTypesOf[lpToken];
    }

    function getLockFarmingContract(address lpToken, uint8 lockType)
        external
        view
        returns (address)
    {
        require(
            lockType < _numLockTypesOf[lpToken],
            "Lock type does not exist"
        );
        return _lockFarmingOf[lpToken][lockType];
    }

    function setOperators(address[] memory operators, bool[] memory isOperators)
        external
        onlyOwner
    {
        require(operators.length == isOperators.length, "Lengths mismatch");
        for (uint256 i = 0; i < operators.length; i++)
            _operators[operators[i]] = isOperators[i];
    }

    function setTotalRewardPerMonth(uint256 rewardAmount)
        external
        onlyOperator
    {
        for (uint256 i = 0; i < lpTokens.length; i++) {
            address savingFarming = _savingFarmingOf[lpTokens[i]];
            SavingFarming(savingFarming).setTotalRewardPerMonth(rewardAmount);
            uint8 numLockTypes = _numLockTypesOf[lpTokens[i]];
            for (uint8 j = 0; j < numLockTypes; j++) {
                address lockFarming = _lockFarmingOf[lpTokens[i]][j];
                LockFarming(lockFarming).setTotalRewardPerMonth(rewardAmount);
            }
        }
    }

    function setRewardWallet(address rewardWallet) external onlyOperator {
        for (uint256 i = 0; i < lpTokens.length; i++) {
            address savingFarming = _savingFarmingOf[lpTokens[i]];
            SavingFarming(savingFarming).setRewardWallet(rewardWallet);
            uint8 numLockTypes = _numLockTypesOf[lpTokens[i]];
            for (uint8 j = 0; j < numLockTypes; j++) {
                address lockFarming = _lockFarmingOf[lpTokens[i]][j];
                LockFarming(lockFarming).setRewardWallet(rewardWallet);
            }
        }
    }

    function createSavingFarming(
        address lpToken,
        address rewardToken,
        address rewardWallet,
        uint256 totalRewardPerMonth
    ) external onlyOperator {
        require(
            _savingFarmingOf[lpToken] == address(0),
            "Saving farming pool created before"
        );
        SavingFarming newSavingContract = new SavingFarming(
            lpToken,
            rewardToken,
            rewardWallet,
            totalRewardPerMonth,
            owner()
        );
        _savingFarmingOf[lpToken] = address(newSavingContract);
        if (!_isLpTokenSupported[lpToken]) {
            lpTokens.push(lpToken);
            _isLpTokenSupported[lpToken] = true;
        }
        emit NewSavingFarming(lpToken, address(newSavingContract));
    }

    function createLockFarming(
        uint256 duration,
        address lpToken,
        address rewardToken,
        address rewardWallet,
        uint256 totalRewardPerMonth
    ) external onlyOperator {
        LockFarming newLockContract = new LockFarming(
            duration,
            lpToken,
            rewardToken,
            rewardWallet,
            totalRewardPerMonth,
            owner()
        );
        if (!_isLpTokenSupported[lpToken]) {
            lpTokens.push(lpToken);
            _isLpTokenSupported[lpToken] = true;
        }
        uint8 lockType = _numLockTypesOf[lpToken];
        _lockFarmingOf[lpToken][lockType] = address(newLockContract);
        _numLockTypesOf[lpToken]++;
        emit NewLockFarming(
            lpToken,
            duration,
            lockType,
            address(newLockContract)
        );
    }

    function emergencyWithdraw(address recipient) external onlyOwner {
        for (uint256 i = 0; i < lpTokens.length; i++) {
            address savingFarming = _savingFarmingOf[lpTokens[i]];
            SavingFarming(savingFarming).emergencyWithdraw(recipient);
            uint8 numLockTypes = _numLockTypesOf[lpTokens[i]];
            for (uint8 j = 0; j < numLockTypes; j++) {
                address lockFarming = _lockFarmingOf[lpTokens[i]][j];
                LockFarming(lockFarming).emergencyWithdraw(recipient);
            }
        }
    }

    function disableRewardToken(address oldRewardToken) external onlyOperator {
        for (uint256 i = 0; i < lpTokens.length; i++) {
            address savingFarmingAddr = _savingFarmingOf[lpTokens[i]];
            SavingFarming savingFarming = SavingFarming(savingFarmingAddr);
            if (
                address(savingFarming.rewardToken()) == oldRewardToken &&
                !savingFarming.paused()
            ) savingFarming.pause();
            uint8 numLockTypes = _numLockTypesOf[lpTokens[i]];
            for (uint8 j = 0; j < numLockTypes; j++) {
                address lockFarmingAddr = _lockFarmingOf[lpTokens[i]][j];
                LockFarming lockFarming = LockFarming(lockFarmingAddr);
                if (
                    address(lockFarming.rewardToken()) == oldRewardToken &&
                    !lockFarming.paused()
                ) lockFarming.pause();
            }
        }
    }

    function enableRewardToken(address rewardToken) external onlyOperator {
        for (uint256 i = 0; i < lpTokens.length; i++) {
            address savingFarmingAddr = _savingFarmingOf[lpTokens[i]];
            SavingFarming savingFarming = SavingFarming(savingFarmingAddr);
            if (
                address(savingFarming.rewardToken()) == rewardToken &&
                savingFarming.paused()
            ) savingFarming.unpause();
            uint8 numLockTypes = _numLockTypesOf[lpTokens[i]];
            for (uint8 j = 0; j < numLockTypes; j++) {
                address lockFarmingAddr = _lockFarmingOf[lpTokens[i]][j];
                LockFarming lockFarming = LockFarming(lockFarmingAddr);
                if (
                    address(lockFarming.rewardToken()) == rewardToken &&
                    lockFarming.paused()
                ) lockFarming.unpause();
            }
        }
    }
}
