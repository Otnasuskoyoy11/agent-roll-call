// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Minimal read-only interface for the Agent ID registry on BNB Chain.
/// @dev Agent ID is SPACE ID Agent ID (ERC-721, non-transferable).
///      Registry: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
///      A return value of balanceOf(account) > 0 means the account holds an Agent ID.
///      This project only ever READS from the registry. It never calls
///      transferFrom, safeTransferFrom, approve, or setApprovalForAll on any contract.
interface IAgentIdRegistry {
    function balanceOf(address account) external view returns (uint256);
}

/// @title AgentRollCall
/// @notice A daily roll call (check-in ledger) that only Agent ID holders can write to.
/// @dev Design constraints, by intent:
///      - NO user funds move: the contract has no payable function, no receive/fallback,
///        no withdrawal function, and holds no tokens or BNB.
///      - NO approvals are ever requested from users.
///      - NO owner exists. The only configuration is the Agent ID registry address,
///        set once in the constructor and stored as `immutable`. There are no admin
///        functions: nothing can be paused, changed, upgraded, minted, taxed, or withdrawn.
///      - The single state-changing function is `checkIn()`, callable only by an
///        address that itself holds an Agent ID, at most once per UTC day.
contract AgentRollCall {
    /// @notice The Agent ID registry this contract gates on. Immutable after deployment.
    IAgentIdRegistry public immutable agentIdRegistry;

    /// @notice Total number of check-ins ever recorded.
    uint256 public totalCheckIns;

    /// @notice Number of distinct Agent ID addresses that have ever checked in.
    uint256 public uniqueAgents;

    /// @notice Per-address roll-call statistics.
    struct Stats {
        uint64 lastDay;       // UTC day number (block.timestamp / 1 days) of the last check-in
        uint64 checkInCount;  // total check-ins by this address
        uint64 currentStreak; // consecutive UTC days, ending at lastDay
        uint64 bestStreak;    // longest streak ever reached by this address
        bool hasInteracted;   // true after the first check-in
    }

    mapping(address => Stats) private _stats;

    /// @notice Emitted on every successful check-in.
    /// @param agent The Agent ID holding address that checked in (always msg.sender).
    /// @param day The UTC day number of this check-in.
    /// @param checkInCount The caller's total check-ins after this one.
    /// @param currentStreak The caller's streak after this check-in.
    event CheckedIn(
        address indexed agent,
        uint256 indexed day,
        uint256 checkInCount,
        uint256 currentStreak
    );

    error NotAgentIdHolder(address account);
    error AlreadyCheckedInToday(address account, uint256 day);
    error ZeroRegistryAddress();

    /// @param registry Address of the Agent ID registry on BNB Chain
    ///        (0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F). Immutable once set.
    constructor(address registry) {
        if (registry == address(0)) revert ZeroRegistryAddress();
        agentIdRegistry = IAgentIdRegistry(registry);
    }

    /// @notice The current UTC day number used for the once-per-day rule.
    function currentDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    /// @notice True if `account` currently holds at least one Agent ID.
    /// @dev This reads the caller's OWN or any address's holder status from the
    ///      public registry only to gate check-ins. The product does not resolve
    ///      names to wallets and offers no lookup of other people's wallets.
    function isAgentIdHolder(address account) public view returns (bool) {
        return agentIdRegistry.balanceOf(account) > 0;
    }

    /// @notice Record today's roll call for the caller.
    /// @dev Requirements: caller holds an Agent ID; caller has not checked in today.
    ///      Moves no funds and requests no approval; the caller only pays the
    ///      network gas of this one transaction, confirmed in their own wallet.
    function checkIn() external {
        if (!isAgentIdHolder(msg.sender)) revert NotAgentIdHolder(msg.sender);

        uint256 today = currentDay();
        Stats storage s = _stats[msg.sender];

        if (s.hasInteracted && uint256(s.lastDay) == today) {
            revert AlreadyCheckedInToday(msg.sender, today);
        }

        bool isFirstCheckIn = !s.hasInteracted;
        if (isFirstCheckIn) {
            s.hasInteracted = true;
            uniqueAgents += 1;
        }

        // Streak: continues only if the previous check-in was exactly yesterday.
        if (!isFirstCheckIn && uint256(s.lastDay) == today - 1) {
            s.currentStreak += 1;
        } else {
            s.currentStreak = 1;
        }
        if (s.currentStreak > s.bestStreak) {
            s.bestStreak = s.currentStreak;
        }

        s.lastDay = uint64(today);
        s.checkInCount += 1;
        totalCheckIns += 1;

        emit CheckedIn(msg.sender, today, s.checkInCount, s.currentStreak);
    }

    /// @notice Read the roll-call statistics for one address.
    /// @return isHolder Whether the address currently holds an Agent ID.
    /// @return checkInCount Total check-ins by the address.
    /// @return streak Current streak (meaningful only if lastDay is today or yesterday).
    /// @return bestStreak Longest streak the address has reached.
    /// @return lastDay UTC day number of the address's last check-in (0 if none).
    /// @return checkedInToday Whether the address has already checked in today.
    function getStats(address account)
        external
        view
        returns (
            bool isHolder,
            uint256 checkInCount,
            uint256 streak,
            uint256 bestStreak,
            uint256 lastDay,
            bool checkedInToday
        )
    {
        Stats storage s = _stats[account];
        isHolder = isAgentIdHolder(account);
        checkInCount = s.checkInCount;
        streak = s.currentStreak;
        bestStreak = s.bestStreak;
        lastDay = s.lastDay;
        checkedInToday = s.hasInteracted && uint256(s.lastDay) == currentDay();
    }
}
