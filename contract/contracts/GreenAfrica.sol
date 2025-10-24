// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * GreenAfrica — Reverse Vending Machine (full on-chain registry + accounting)
 *
 * Design goals:
 * - Web3 abstracted: only an admin/operator wallet writes to chain on behalf of devices & users.
 * - One source of truth for deposits, points, referrals, redemptions, and device registration.
 * - Mirror Node friendly: important fields are indexed; rich events for analytics.
 * - No user wallets required; we key users by a bytes32 "Green ID" (e.g., hash of phone/email).
 * - RVM stores S3 video key off-chain; only the opaque string is saved on-chain.
 *
 * Key IDs:
 * - recyclerId: bytes32 (Green ID). Your backend generates and manages this.
 * - rvmId:      bytes32 (unique per device).
 * - sessionId:  bytes32 (unique per deposit session, e.g., uuid v4 hashed).
 * - redemptionId: bytes32 (unique per redemption request).
 *
 * Coordinates:
 * - latE6/lngE6 are stored as int32 microdegrees (deg * 1e6), enough for Nigeria & beyond.
 */

contract GreenAfrica {
    // ----------------------------
    // Access control (admin + ops)
    // ----------------------------
    address public owner;
    mapping(address => bool) public operators;
    bool    public paused;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    modifier onlyWriter() {
        require(msg.sender == owner || operators[msg.sender], "Not authorized");
        _;
    }
    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    // ----------------------------
    // Referral config (basis points)
    // e.g., 1000 = 10.00%
    // ----------------------------
    uint16 public referralBps = 1000; // default 10%

    // ----------------------------
    // Data models
    // ----------------------------
    struct RVM {
        bool   exists;
        bool   active;
        int32  latE6;
        int32  lngE6;
        string name;
        string metaURI; // optional extra info
    }

    struct User {
        bool    exists;
        bytes32 recyclerId;       // same as key
        bytes32 referralCode;     // unique code this user can share
        bytes32 referredBy;       // referrer's recyclerId (resolved from the code)
        bool    hasRecycled;      // true after first successful deposit
        uint64  firstDepositAt;   // timestamp of first deposit (if any)
        uint256 points;           // current balance
        uint256 totalPET;         // lifetime PET count
    }

    // ----------------------------
    // Storage
    // ----------------------------
    mapping(bytes32 => RVM)   public rvms;
    mapping(bytes32 => User)  public users;
    mapping(bytes32 => bytes32) public referralCodeToUser; // code => recyclerId

    bytes32[] public rvmIds;     // enumerable for convenience (small scale)
    bytes32[] public userIds;    // enumerable for convenience (small scale)

    // ----------------------------
    // Events (Mirror Node friendly)
    // ----------------------------
    event AdminUpdated(address indexed who, bool isOperator);
    event OwnerTransferred(address indexed oldOwner, address indexed newOwner);
    event Paused(bool indexed value);

    event ReferralConfigUpdated(uint16 bps);

    event RVMRegistered(
        bytes32 indexed rvmId,
        int32 latE6,
        int32 lngE6,
        string name,
        string metaURI
    );
    event RVMStatusUpdated(bytes32 indexed rvmId, bool indexed active);

    event RecyclerRegistered(
        bytes32 indexed recyclerId,
        bytes32 referralCode,
        bytes32 indexed referredBy
    );
    event ReferrerSet(bytes32 indexed recyclerId, bytes32 indexed referredBy);

    event DepositRecorded(
        bytes32 indexed recyclerId,
        bytes32 indexed rvmId,
        uint256 petCount,
        uint256 pointsAwarded,
        string  s3URI,
        bytes32 indexed sessionId,
        uint256 timestamp
    );
    event ReferralPaid(
        bytes32 indexed referrerId,
        bytes32 indexed referredId,
        uint256 rewardPoints
    );

    event PointsAdjusted(
        bytes32 indexed recyclerId,
        int256  delta,
        string  reason,
        uint256 newBalance
    );

    event PointsRedeemed(
        bytes32 indexed recyclerId,
        uint256 points,
        string  rewardType,   // "AIRTIME" | "DATA" | etc.
        string  destination,  // msisdn or other
        bytes32 indexed redemptionId,
        uint256 timestamp
    );

    // ----------------------------
    // Constructor
    // ----------------------------
    constructor() {
        owner = msg.sender;
    }

    // ----------------------------
    // Admin functions
    // ----------------------------
    function setPaused(bool value) external onlyOwner {
        paused = value;
        emit Paused(value);
    }

    function setOperator(address who, bool isOp) external onlyOwner {
        operators[who] = isOp;
        emit AdminUpdated(who, isOp);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero addr");
        address old = owner;
        owner = newOwner;
        emit OwnerTransferred(old, newOwner);
    }

    function setReferralBps(uint16 bps) external onlyOwner {
        require(bps <= 10_000, "bps > 100%");
        referralBps = bps;
        emit ReferralConfigUpdated(bps);
    }

    // ----------------------------
    // RVM registration / updates
    // ----------------------------
    function registerRVM(
        bytes32 rvmId,
        int32 latE6,
        int32 lngE6,
        string calldata name,
        string calldata metaURI
    ) external onlyWriter {
        require(rvmId != bytes32(0), "rvmId=0");
        RVM storage r = rvms[rvmId];
        require(!r.exists, "RVM exists");

        rvms[rvmId] = RVM({
            exists:  true,
            active:  true,
            latE6:   latE6,
            lngE6:   lngE6,
            name:    name,
            metaURI: metaURI
        });
        rvmIds.push(rvmId);
        emit RVMRegistered(rvmId, latE6, lngE6, name, metaURI);
    }

    function updateRVM(
        bytes32 rvmId,
        int32 latE6,
        int32 lngE6,
        bool   active,
        string calldata name,
        string calldata metaURI
    ) external onlyWriter {
        RVM storage r = rvms[rvmId];
        require(r.exists, "RVM !exists");

        r.latE6   = latE6;
        r.lngE6   = lngE6;
        r.active  = active;
        r.name    = name;
        r.metaURI = metaURI;

        emit RVMRegistered(rvmId, latE6, lngE6, name, metaURI);
        emit RVMStatusUpdated(rvmId, active);
    }

    function setRVMActive(bytes32 rvmId, bool active) external onlyWriter {
        RVM storage r = rvms[rvmId];
        require(r.exists, "RVM !exists");
        r.active = active;
        emit RVMStatusUpdated(rvmId, active);
    }

    // ----------------------------
    // User / Referral management
    // ----------------------------
    /**
     * Register a recycler (Green ID).
     * - referralCode must be unique if provided (non-zero).
     * - referredByCode is optional; if provided and resolvable, we bind it.
     */
    function registerRecycler(
        bytes32 recyclerId,
        bytes32 referralCode,
        bytes32 referredByCode
    ) external onlyWriter {
        require(recyclerId != bytes32(0), "recyclerId=0");
        require(!users[recyclerId].exists, "User exists");

        bytes32 referrerId = bytes32(0);
        if (referredByCode != bytes32(0)) {
            referrerId = referralCodeToUser[referredByCode];
        }

        if (referralCode != bytes32(0)) {
            require(referralCodeToUser[referralCode] == bytes32(0), "code in use");
            referralCodeToUser[referralCode] = recyclerId;
        }

        users[recyclerId] = User({
            exists:        true,
            recyclerId:    recyclerId,
            referralCode:  referralCode,
            referredBy:    referrerId,
            hasRecycled:   false,
            firstDepositAt: 0,
            points:        0,
            totalPET:      0
        });

        userIds.push(recyclerId);
        emit RecyclerRegistered(recyclerId, referralCode, referrerId);
    }

    /**
     * Set or change referrer before first recycling.
     */
    function setReferrer(bytes32 recyclerId, bytes32 referredByCode) external onlyWriter {
        User storage u = users[recyclerId];
        require(u.exists, "User !exists");
        require(!u.hasRecycled, "Already recycled");
        bytes32 newRef = bytes32(0);
        if (referredByCode != bytes32(0)) {
            newRef = referralCodeToUser[referredByCode];
            require(newRef != bytes32(0), "Bad code");
            require(newRef != recyclerId, "Self ref");
        }
        u.referredBy = newRef;
        emit ReferrerSet(recyclerId, newRef);
    }

    // ----------------------------
    // Core: record deposit
    // ----------------------------
    /**
     * Record a deposit session:
     * - Validates user/RVM existence and RVM active.
     * - Adds PET + points to user.
     * - One-time referral payout (bps of awarded points) on user's first successful recycling.
     * - Emits a rich event for Mirror Node analytics.
     */
    function recordDeposit(
        bytes32 recyclerId,
        bytes32 rvmId,
        uint256 petCount,
        uint256 pointsAwarded,
        string  calldata s3URI,
        bytes32 sessionId
    ) external onlyWriter whenNotPaused {
        require(petCount > 0, "pet=0");
        require(pointsAwarded > 0, "points=0");
        require(sessionId != bytes32(0), "sessionId=0");

        User storage u = users[recyclerId];
        require(u.exists, "User !exists");
        RVM storage rvm = rvms[rvmId];
        require(rvm.exists && rvm.active, "RVM invalid");

        // Update user
        u.totalPET += petCount;
        u.points   += pointsAwarded;

        // If first time recycling, store timestamp and pay referral (if set)
        if (!u.hasRecycled) {
            u.hasRecycled   = true;
            u.firstDepositAt = uint64(block.timestamp);

            if (u.referredBy != bytes32(0) && referralBps > 0) {
                uint256 reward = (pointsAwarded * referralBps) / 10_000;
                if (reward > 0) {
                    users[u.referredBy].points += reward;
                    emit ReferralPaid(u.referredBy, recyclerId, reward);
                }
            }
        }

        emit DepositRecorded(
            recyclerId,
            rvmId,
            petCount,
            pointsAwarded,
            s3URI,
            sessionId,
            block.timestamp
        );
        emit PointsAdjusted(recyclerId, int256(pointsAwarded), "deposit_award", u.points);
    }

    // ----------------------------
    // Adjust points (admin corrections)
    // ----------------------------
    function adjustPoints(
        bytes32 recyclerId,
        int256 delta,
        string calldata reason
    ) external onlyWriter {
        User storage u = users[recyclerId];
        require(u.exists, "User !exists");

        if (delta >= 0) {
            u.points += uint256(delta);
        } else {
            uint256 absd = uint256(-delta);
            require(u.points >= absd, "Insufficient");
            u.points -= absd;
        }
        emit PointsAdjusted(recyclerId, delta, reason, u.points);
    }

    // ----------------------------
    // Redeem points (airtime/data)
    // ----------------------------
    /**
     * Deduct points and emit a redemption request event.
     * Off-chain service performs the actual top-up and (optionally) writes any completion note off-chain.
     */
    function redeemPoints(
        bytes32 recyclerId,
        uint256 points,
        string calldata rewardType,   // "AIRTIME" | "DATA" | etc.
        string calldata destination,  // e.g., MSISDN
        bytes32 redemptionId
    ) external onlyWriter whenNotPaused {
        require(points > 0, "points=0");
        require(redemptionId != bytes32(0), "redemptionId=0");

        User storage u = users[recyclerId];
        require(u.exists, "User !exists");
        require(u.points >= points, "Insufficient points");

        u.points -= points;

        emit PointsRedeemed(
            recyclerId,
            points,
            rewardType,
            destination,
            redemptionId,
            block.timestamp
        );
        emit PointsAdjusted(recyclerId, -int256(points), "redeem", u.points);
    }

    // ----------------------------
    // Reads
    // ----------------------------
    function getUser(bytes32 recyclerId) external view returns (
        bool exists,
        bytes32 _recyclerId,
        bytes32 referralCode,
        bytes32 referredBy,
        bool hasRecycled,
        uint64 firstDepositAt,
        uint256 points,
        uint256 totalPET
    ) {
        User memory u = users[recyclerId];
        return (
            u.exists,
            u.recyclerId,
            u.referralCode,
            u.referredBy,
            u.hasRecycled,
            u.firstDepositAt,
            u.points,
            u.totalPET
        );
    }

    function getRVM(bytes32 rvmId) external view returns (
        bool exists,
        bool active,
        int32 latE6,
        int32 lngE6,
        string memory name,
        string memory metaURI
    ) {
        RVM storage r = rvms[rvmId];
        return (r.exists, r.active, r.latE6, r.lngE6, r.name, r.metaURI);
    }

    function allRVMIds() external view returns (bytes32[] memory) {
        return rvmIds;
    }
    function allUserIds() external view returns (bytes32[] memory) {
        return userIds;
    }
}
