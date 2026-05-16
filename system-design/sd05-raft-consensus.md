# Chapter 5: Raft Consensus & Leader Election

> **Chapter goal:** Understand how Raft achieves distributed consensus — leader election, log replication, safety guarantees — and implement a simplified Raft state machine demonstrating term tracking and vote counting.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 The Consensus Problem

A distributed system is useful only if multiple nodes agree on a sequence of values — the **state machine replication** problem. Consider a key-value store with three replicas. If a client writes `X = 1`, all three replicas must apply that write in the same position in their log. If they disagree on ordering, the replicas diverge and the system becomes inconsistent.

**Raft's goal**: given N nodes, ensure all live nodes apply the same sequence of commands in the same order, even when up to `⌊(N-1)/2⌋` nodes fail.

A correct consensus algorithm must satisfy:
- **Safety**: Only one leader per term. An entry committed by the leader has been stored on a quorum of nodes and will never be lost, even across leader changes.
- **Liveness**: If a quorum of nodes is alive and can communicate, the system makes progress — it elects a leader and commits new entries.
- **Agreement**: No two nodes ever apply different commands at the same log index.

### 1.2 Quorum Requirements

A quorum is the minimum number of nodes that must agree for an operation to succeed. Raft requires a simple majority — `quorum = ⌊N/2⌋ + 1`.

| Cluster Size | Quorum | Max Failures Tolerated |
|---|---|---|
| 3 nodes | 2 | 1 |
| 5 nodes | 3 | 2 |
| 7 nodes | 4 | 3 |
| 9 nodes | 5 | 4 |

Larger clusters tolerate more failures but incur higher coordination overhead — every write must be acknowledged by more nodes before committing. The common production sweet spot is **5 nodes** (tolerates 2 simultaneous failures while not paying the overhead of 7).

### 1.3 Scale Context

In a 5-node Raft cluster handling 10,000 client writes/second:

- Each write requires the leader to send `AppendEntries` to 4 followers.
- A commit requires 3 ACKs (quorum). The 4th and 5th nodes' ACKs arrive later and are counted but not waited on.
- Network round-trip within a single data center: ~1 ms. Write commit latency: ~1–2 ms.
- Cross-continent (multi-region Raft): round-trip ~100 ms. Commit latency: ~100–200 ms. This is why multi-region Raft is rare — use asynchronous replication instead, with Raft only within a region.

---

## 2. High-Level Architecture

### 2.1 Normal Operation — Leader Drives Replication

```
                     Client
                        │
                  write X=1
                        │
                        ▼
    ┌─────────────────────────────────────────────────────────┐
    │                5-Node Raft Cluster                       │
    │                                                          │
    │         ┌─────────────────┐                             │
    │         │  N1 (LEADER)    │◄─── Client writes land here │
    │         │  term=3, log=[1]│                             │
    │         └────────┬────────┘                             │
    │    AppendEntries │  (broadcast to all followers)        │
    │        ┌─────────┼─────────┐                            │
    │        ▼         ▼         ▼                            │
    │  ┌──────────┐ ┌──────────┐ ┌──────────┐                │
    │  │N2 (follower)│N3(follower)│N4(follower)│               │
    │  │log=[1]   │ │log=[1]   │ │log=[1]   │               │
    │  └──────────┘ └──────────┘ └──────────┘                │
    │       ACK          ACK                                   │
    │        └─────────────────────────────────────────────►  │
    │   Quorum (3/5) reached → entry COMMITTED                 │
    │   Leader sends commitIndex in next heartbeat →           │
    │   All followers apply X=1 to their state machine        │
    │                                                          │
    │   N5 (follower — slow or temporarily partitioned)        │
    │   Catches up on next AppendEntries or heartbeat          │
    └─────────────────────────────────────────────────────────┘
```

### 2.2 Leader Failure and Re-election

```
  ════════════════════ LEADER FAILURE SCENARIO ════════════════════

  Before failure:
    N1=Leader(term=3), N2=Follower, N3=Follower, N4=Follower, N5=Follower

  N1 crashes. Followers stop receiving heartbeats.

  ┌─── Election Timeout Fires (150–300 ms random) ───┐
  │  N2 times out first → becomes CANDIDATE           │
  │  Increments term: term=4, votes for self (1 vote) │
  │  Sends RequestVote(term=4, lastLogTerm=3, ...)     │
  └───────────────────────────────────────────────────┘
          │
          │ RequestVote ──────────────────────────────────────►
          │                N3 replies: GRANTED (term=4)
          │                N4 replies: GRANTED (term=4)
          │                N5 replies: GRANTED (term=4)
          │
  N2 has 4 votes (self + N3 + N4 + N5) ≥ quorum(3) → N2 becomes LEADER

  ┌─── N2 now Leader(term=4) ───────────────────────┐
  │  Immediately sends AppendEntries (heartbeats)    │
  │  All followers update to term=4                  │
  │  If N1 recovers, it receives term=4 heartbeat →  │
  │  steps down to Follower(term=4)                  │
  └─────────────────────────────────────────────────┘

  Key safety property: N2 only wins if its log is at least
  as up-to-date as any voter's log. Stale candidates are rejected.
  ════════════════════════════════════════════════════════════════
```

---

## 3. Component Deep-Dive

### 3.1 Terms — Raft's Logical Clock

A **term** is a monotonically increasing integer. Raft divides time into terms; each term begins with an election. A term has at most one leader — if a candidate wins the election, it leads for that term. If no candidate wins (split vote), the term ends with no leader, and a new term begins with another election.

Terms serve as Raft's logical clock: they detect stale information from old leaders. Every Raft message carries the sender's current term. If a node receives a message with a term higher than its own, it immediately updates its term and reverts to follower status. If a node receives a message with a *lower* term, it rejects the message — the sender is operating on stale information.

This mechanism prevents old leaders from causing damage. If N1 was leader in term 3 but crashed and recovered while term 4 is underway, it will receive a heartbeat from the term-4 leader and immediately step down. It cannot confuse followers by sending term-3 AppendEntries — they will reject it.

### 3.2 Leader Election

**Step 1 — Election Timeout**: Each follower maintains an election timer reset to a random value between 150 ms and 300 ms whenever it receives a heartbeat. If no heartbeat arrives before the timer fires, the follower assumes the leader has failed.

**Step 2 — Become Candidate**: The follower increments its `currentTerm`, transitions to the `Candidate` state, and votes for itself. It then sends `RequestVote` RPCs to all other nodes.

**Step 3 — RequestVote Grant Rules**: A node grants its vote if:
1. The candidate's term is ≥ the voter's `currentTerm`.
2. The voter has not yet voted in this term (or already voted for this candidate).
3. The candidate's log is at least as up-to-date as the voter's log (see Election Restriction, Section 3.5).

**Step 4 — Win or Retry**: The candidate wins if it receives votes from a quorum. It immediately transitions to leader and sends heartbeat `AppendEntries` to establish authority. If the candidate sees a heartbeat from another node with an equal or higher term, it steps down to follower. If neither happens and the election timer fires again, the candidate starts a new election with an incremented term.

**Random Timeout Prevents Livelock**: If all nodes had identical timeouts, they would all become candidates simultaneously and split votes indefinitely. Randomizing the timeout (150–300 ms) ensures one node fires first with high probability, getting a head start in collecting votes. The probability of a persistent split vote in a 5-node cluster with 150–300 ms random timeouts is negligible in practice.

### 3.3 Log Replication

The Raft log is an ordered sequence of entries. Each entry contains:
- **term**: the term in which the leader created this entry.
- **index**: the position in the log (1-based, monotonically increasing).
- **command**: the state machine command (e.g., `SET X = 1`).

**Replication flow**:
1. Client sends a command to the leader.
2. Leader appends the entry to its local log (`term=T, index=I, cmd=X`).
3. Leader sends `AppendEntries(term, leaderCommit, prevLogIndex, prevLogTerm, entries[])` to all followers.
4. Each follower appends the entry to its log and responds with success.
5. When the leader receives success from a quorum (including itself), the entry is **committed**.
6. Leader applies the committed entry to its state machine and responds to the client.
7. Leader piggybacks `leaderCommit` on the next heartbeat. Followers advance their `commitIndex` and apply newly committed entries.

**Heartbeats**: The leader sends empty `AppendEntries` (heartbeats) periodically (typically every 50 ms) to prevent followers from timing out and starting elections. Heartbeats also carry the current `commitIndex`.

### 3.4 Log Matching Property

The **Log Matching Property** is a key safety invariant Raft maintains:

> If two logs contain an entry with the same index and term, then the logs are identical in all entries up through that index.

This is enforced by the `AppendEntries` consistency check: when the leader sends entries starting at index `I`, it includes `prevLogIndex = I - 1` and `prevLogTerm = term of entry at I-1`. The follower rejects the append if its entry at `prevLogIndex` does not match `prevLogTerm`. The leader then decrements its `nextIndex` for that follower and retries, walking back until it finds a common prefix. The leader then overwrites the follower's diverging tail with its own entries.

This check guarantees that once a follower accepts an entry, its log prefix up to that point is identical to the leader's.

### 3.5 Safety: Election Restriction

The most critical safety property: **a leader must have all committed entries in its log when it is elected**. Otherwise, a newly elected leader could overwrite committed entries on followers.

Raft enforces this with the **up-to-date log** check in RequestVote:

> A candidate's log is "more up-to-date" than a voter's log if:
> - The candidate's last log entry has a **higher term** than the voter's last entry, OR
> - The terms are equal and the candidate's log is **longer** (higher index).

A voter only grants its vote if the candidate's log is at least as up-to-date as its own. Since committed entries are on a quorum of nodes, any winning candidate must get votes from at least one node in that quorum — and therefore must have a log at least as up-to-date as that node, ensuring it has all committed entries.

### 3.6 Snapshotting

The Raft log grows without bound as commands accumulate. Storing years of log entries wastes disk space and slows down new node catch-up. Snapshotting solves this:

1. When the log reaches a configurable size (e.g., 64 MB), the leader takes a **snapshot**: a serialized image of the state machine at the current `commitIndex`.
2. The leader discards log entries up to the snapshot's index.
3. New or slow nodes receive the snapshot via **`InstallSnapshot` RPC** — the leader sends the snapshot in chunks; the follower replaces its state machine state with the snapshot and sets its log to start just after the snapshot index.

Snapshotting is independent of consensus — each node can snapshot at its own pace. The key constraint: never discard a log entry that has not yet been applied to the local state machine (otherwise you lose state transitions).

### 3.7 Real-World Raft Deployments

Raft has become the consensus algorithm of choice for production distributed systems:

- **etcd**: The key-value store that backs Kubernetes. Every Kubernetes cluster state change (pod creation, deployment update, service registration) is a Raft log entry committed to etcd. etcd uses a 3 or 5-node Raft cluster.
- **TiKV**: The storage layer of TiDB (distributed SQL). Uses **Multi-Raft**: each data shard (Region, ~96 MB) has its own Raft group. A 1 TB database might have ~10,000 concurrent Raft groups.
- **CockroachDB**: Distributed SQL database. Uses Multi-Raft for range-based sharding, with each range replicated across 3+ nodes.
- **Consul**: Service mesh and distributed coordination. Uses Raft for its key-value store and service catalog.
- **HashiCorp Vault**: Secret management. Uses Raft integrated storage for HA mode.

**Multi-Raft** is the key pattern for scalability: rather than running one Raft group for the entire dataset (which would serialize all writes through a single leader), you partition data into shards and run independent Raft groups per shard. Write throughput scales linearly with the number of shards.

---

## 4. Key Algorithms

### 4.1 Rust — Raft State Machine

```rust
#[derive(PartialEq, Debug)]
enum NodeState {
    Follower,
    Candidate,
    Leader,
}

struct RaftNode {
    id: usize,
    state: NodeState,
    current_term: u64,
    voted_for: Option<usize>,
    // votes_received counts total votes including self-vote.
    // Self-vote is counted in start_election.
    votes_received: usize,
    cluster_size: usize,
}

impl RaftNode {
    fn new(id: usize, cluster_size: usize) -> Self {
        RaftNode {
            id,
            state: NodeState::Follower,
            current_term: 0,
            voted_for: None,
            votes_received: 0,
            cluster_size,
        }
    }

    /// quorum is the minimum votes needed to win an election.
    fn quorum(&self) -> usize {
        self.cluster_size / 2 + 1
    }

    /// Transition to Candidate: increment term, vote for self, return new term.
    /// Self-vote is counted immediately (votes_received = 1).
    fn start_election(&mut self) -> u64 {
        self.current_term += 1;
        self.state = NodeState::Candidate;
        self.voted_for = Some(self.id);
        self.votes_received = 1; // self-vote
        self.current_term
    }

    /// Record one incoming vote grant. Returns true if this vote causes
    /// the node to become Leader (votes_received just reached quorum).
    fn receive_vote(&mut self) -> bool {
        if self.state != NodeState::Candidate {
            return false;
        }
        self.votes_received += 1;
        if self.votes_received >= self.quorum() {
            self.state = NodeState::Leader;
            return true;
        }
        false
    }

    /// Upon receiving a message with a higher term, step down to Follower.
    fn receive_higher_term(&mut self, term: u64) {
        if term > self.current_term {
            self.current_term = term;
            self.state = NodeState::Follower;
            self.voted_for = None;
            self.votes_received = 0;
        }
    }
}

fn main() {
    // Test 1: 3-node election — node 0 starts election, gets 1 additional
    //         vote from another node, reaches quorum=2, becomes leader.
    let mut node = RaftNode::new(0, 3);
    let term = node.start_election();
    assert_eq!(term, 1, "term should increment to 1");
    assert_eq!(node.state, NodeState::Candidate);
    assert_eq!(node.votes_received, 1, "self-vote counted");
    assert_eq!(node.quorum(), 2, "quorum for 3-node cluster is 2");

    // One more vote arrives → total = 2, quorum reached → Leader
    let became_leader = node.receive_vote();
    assert!(became_leader, "should become leader after reaching quorum");
    assert_eq!(node.state, NodeState::Leader);

    // Test 2: leader receives higher term → steps down to follower
    let mut leader = RaftNode::new(1, 5);
    leader.start_election();
    leader.receive_vote(); // 2 votes
    leader.receive_vote(); // 3 votes → quorum=3 for 5-node cluster
    assert_eq!(leader.state, NodeState::Leader);

    leader.receive_higher_term(10);
    assert_eq!(leader.state, NodeState::Follower);
    assert_eq!(leader.current_term, 10);
    assert!(leader.voted_for.is_none(), "voted_for cleared on step-down");

    // Test 3: split vote — node starts election in 3-node cluster,
    //         gets 0 additional votes (only self-vote), stays candidate.
    let mut split = RaftNode::new(2, 3);
    split.start_election();
    // No receive_vote() calls — only 1 vote (self), quorum=2 → stays candidate
    assert_eq!(split.state, NodeState::Candidate);
    assert_eq!(split.votes_received, 1);

    println!("All Raft state machine assertions passed.");
    println!("node0 state:  {:?}, term: {}", node.state, node.current_term);
    println!("leader state: {:?}, term: {}", leader.state, leader.current_term);
    println!("split state:  {:?}, votes: {}", split.state, split.votes_received);
}
```

### 4.2 Java — Raft State Machine

```java
public class RaftNode {
    enum NodeState { FOLLOWER, CANDIDATE, LEADER }

    private int id;
    private NodeState state;
    private long currentTerm;
    // Integer (boxed) allows null to mean "has not voted this term"
    private Integer votedFor;
    // votes_received counts total votes including self-vote.
    private int votesReceived;
    private int clusterSize;

    public RaftNode(int id, int clusterSize) {
        this.id = id;
        this.clusterSize = clusterSize;
        this.state = NodeState.FOLLOWER;
        this.currentTerm = 0L;
        this.votedFor = null;
        this.votesReceived = 0;
    }

    /** Quorum = majority of cluster. */
    public int quorum() {
        return clusterSize / 2 + 1;
    }

    /**
     * Transition to CANDIDATE: increment term, vote for self, return new term.
     * Self-vote is counted immediately (votesReceived = 1).
     */
    public long startElection() {
        currentTerm += 1;
        state = NodeState.CANDIDATE;
        votedFor = id;
        votesReceived = 1; // self-vote
        return currentTerm;
    }

    /**
     * Record one incoming vote grant.
     * Returns true if this vote causes the node to become LEADER.
     */
    public boolean receiveVote() {
        if (state != NodeState.CANDIDATE) return false;
        votesReceived += 1;
        if (votesReceived >= quorum()) {
            state = NodeState.LEADER;
            return true;
        }
        return false;
    }

    /**
     * Upon receiving a message with a higher term, step down to FOLLOWER.
     */
    public void receiveHigherTerm(long term) {
        if (term > currentTerm) {
            currentTerm = term;
            state = NodeState.FOLLOWER;
            votedFor = null;
            votesReceived = 0;
        }
    }

    public NodeState getState() { return state; }
    public long getCurrentTerm() { return currentTerm; }
    public Integer getVotedFor() { return votedFor; }
    public int getVotesReceived() { return votesReceived; }

    public static void main(String[] args) {
        // Test 1: 3-node election — node 0 starts election, gets 1 additional
        //         vote, reaches quorum=2, becomes leader.
        RaftNode node = new RaftNode(0, 3);
        long term = node.startElection();
        if (term != 1)
            throw new AssertionError("term should be 1, got " + term);
        if (node.getState() != NodeState.CANDIDATE)
            throw new AssertionError("should be CANDIDATE");
        if (node.getVotesReceived() != 1)
            throw new AssertionError("self-vote should give votes=1");
        if (node.quorum() != 2)
            throw new AssertionError("quorum for 3-node cluster should be 2");

        boolean becameLeader = node.receiveVote(); // 2nd vote → quorum
        if (!becameLeader)
            throw new AssertionError("should become leader on quorum");
        if (node.getState() != NodeState.LEADER)
            throw new AssertionError("state should be LEADER");

        // Test 2: leader receives higher term → steps down to follower
        RaftNode leader = new RaftNode(1, 5);
        leader.startElection();
        leader.receiveVote(); // 2 votes
        leader.receiveVote(); // 3 votes → quorum=3 for 5-node cluster
        if (leader.getState() != NodeState.LEADER)
            throw new AssertionError("should be LEADER after quorum");

        leader.receiveHigherTerm(10L);
        if (leader.getState() != NodeState.FOLLOWER)
            throw new AssertionError("should step down to FOLLOWER");
        if (leader.getCurrentTerm() != 10L)
            throw new AssertionError("term should update to 10");
        if (leader.getVotedFor() != null)
            throw new AssertionError("votedFor should be null after step-down");

        // Test 3: split vote — node starts election in 3-node cluster,
        //         receives 0 additional votes (only self-vote=1), stays candidate.
        RaftNode split = new RaftNode(2, 3);
        split.startElection();
        // No receiveVote() calls — only self-vote, quorum=2 → stays CANDIDATE
        if (split.getState() != NodeState.CANDIDATE)
            throw new AssertionError("should remain CANDIDATE without quorum");
        if (split.getVotesReceived() != 1)
            throw new AssertionError("should have exactly 1 vote (self)");

        System.out.println("All Raft state machine assertions passed.");
        System.out.println("node state: " + node.getState() + ", term: " + node.getCurrentTerm());
        System.out.println("leader state: " + leader.getState() + ", term: " + leader.getCurrentTerm());
        System.out.println("split state: " + split.getState() + ", votes: " + split.getVotesReceived());
    }
}
```

---

## 5. Tradeoffs

### 5.1 Raft vs Other Consensus Algorithms

| Aspect | Raft | Paxos (Single-Decree) | Multi-Paxos | Zab (Zookeeper) |
|---|---|---|---|---|
| **Understandability** | High — designed explicitly for comprehension | Low — subtle liveness conditions, many variants | Medium — pipeline adds complexity | Medium — similar to Raft, less documented |
| **Liveness** | Strong — random timeout prevents livelock | Weak — Paxos can livelock (two leaders competing) | Improved via leader lease | Strong — epoch-based leader prevents competition |
| **Leader-based** | Yes — single leader per term | No built-in leader concept | Yes — distinguished proposer | Yes — primary-backup model |
| **Log Ordering** | Strict — one outstanding entry at a time (vanilla) | Per-slot agreement, no global order built-in | Pipelined — multiple entries in flight | Strict — primary orders all writes |
| **Production Usage** | etcd, TiKV, CockroachDB, Consul, Vault | Academic baseline; few direct implementations | Chubby (Google), some custom implementations | Zookeeper |
| **Snapshots** | Built-in (InstallSnapshot RPC) | Not specified — implementation-specific | Not specified | Built-in fuzzy snapshots |

### 5.2 Raft's Design Philosophy

Raft was designed by Diego Ongaro and John Ousterhout at Stanford (2014) with **understandability as the primary goal**, not maximum performance. The paper's user study showed that students understood Raft significantly better than Paxos after equivalent study time.

Key choices that prioritize understandability over raw performance:

- **Vanilla Raft allows only one outstanding log entry at a time**: the leader cannot pipeline multiple entries without receiving an ACK for each. This simplifies the protocol but limits throughput. Production implementations (like etcd's) relax this with batching and pipelining.
- **Leader completeness**: once a leader is elected, all committed entries are guaranteed to be on its log. This prevents complex recovery scenarios where a new leader must discover committed entries by querying other nodes.
- **Randomized timeouts instead of clocks**: avoiding synchronized clocks simplifies the model, at the cost of non-deterministic election timing.

### 5.3 Multi-Raft for Scalability

Vanilla Raft bottlenecks at one leader for the entire dataset. **Multi-Raft** runs independent Raft groups per shard:

```
Shard A: [N1-leader, N2, N3]   ← independent Raft group
Shard B: [N2-leader, N3, N4]   ← independent Raft group
Shard C: [N3-leader, N4, N5]   ← independent Raft group
```

Each shard processes writes independently. A 5-node cluster with 100 shards can sustain 100× the write throughput of a single Raft group. The coordination overhead per shard is the same; the gains are in parallelism.

The complexity cost: shard splits and merges require transferring Raft group membership, which involves leader transfers, log transfers, and careful bookkeeping.

---

## 6. Failure Modes

### 6.1 Election Livelock

**Symptom**: Multiple candidates repeatedly start elections simultaneously, each failing to reach quorum because votes are split evenly. The cluster makes no progress — no leader is ever elected.

**How Raft prevents this**: Random election timeouts (150–300 ms) ensure that in most cases one node fires first, becomes a candidate, and wins before others time out. The probability of two nodes firing within the same ~1 ms window is low in a 5-node cluster.

**PreVote extension**: Even with randomized timeouts, a transient network partition can cause a node to increment its term and disrupt an otherwise stable cluster when it reconnects. The **PreVote** optimization (used in etcd) adds a pre-election phase: before incrementing its term, a candidate asks "would you vote for me if I started an election?" Nodes grant a pre-vote only if they haven't received a heartbeat recently. This prevents a rejoining node from unnecessarily triggering a new election.

### 6.2 Leader Isolation

**Symptom**: The leader becomes partitioned from the majority of followers. It continues receiving client writes, appending them to its log, and sending `AppendEntries` — but can never reach quorum. Those writes are buffered but never committed. The majority side elects a new leader. When the old leader's partition heals, it discovers a higher term, steps down, and its uncommitted entries are overwritten.

**From the client's perspective**: writes sent to the isolated leader appear to succeed (the leader accepted the request) but are never committed. The client does not receive a response (the leader is waiting for quorum). A well-implemented client times out and retries against the new leader.

**Mitigation**: 
- *Read-index*: before serving a read, the leader confirms with a quorum that it is still the current leader. This prevents stale reads from an isolated leader.
- *Lease reads*: the leader assumes its lease is valid for one election-timeout window after its last quorum communication. Reads within the lease window are served without a round-trip. Requires bounded clock skew.

### 6.3 Log Divergence After Crash

**Symptom**: A node crashes while the leader is replicating an entry. The node had appended the entry to its log but crashed before sending the ACK. On restart, the node's log has an entry the leader may or may not have committed.

**Raft's resolution**: When the crashed node reconnects, the leader sends `AppendEntries` with a consistency check. If the node's log diverges (has uncommitted entries from a previous term that were not replicated to a quorum), the leader identifies the divergence point and overwrites the follower's log from that point forward with the leader's entries.

Crucially: **only uncommitted entries can be overwritten**. Committed entries, by definition, were on a quorum of nodes — the new leader must have them on its log (Election Restriction). So overwriting only affects entries that the old leader never committed.

### 6.4 Slow Follower

**Symptom**: In a 3-node cluster (quorum = 2), one slow follower with high disk or network latency forces the leader to wait for it before committing each entry, as it is always the 2nd (necessary) ACK.

**Why this matters**: The leader commits when it has `quorum` ACKs. In a 3-node cluster, the leader needs 2 ACKs (including itself). If follower N2 is fast and N3 is slow, every commit waits for N3 (since the leader needs 2 total: leader + one follower). If N3 is 50 ms slower than N2, the cluster's commit latency is 50 ms higher than optimal.

**Mitigation**:
- Use a **5-node cluster**: quorum = 3. The leader waits for the 2 fastest followers to ACK. The 3rd and 4th follower ACKs are absorbed asynchronously. One slow node no longer blocks commits.
- **Follower read offload**: route read-only queries to followers (with read-index or lease) to reduce leader load and give the slow follower fewer competing writes to process.
- **Pipeline AppendEntries**: batch multiple log entries into a single `AppendEntries` RPC to amortize per-RPC overhead for slow links.

---

## 7. Java vs Rust Callout

### 7.1 Enums with Behavior

**Rust enum with `impl` block**: Rust enums are algebraic types. An enum variant can carry data (e.g., `Leader { term: u64 }`), and behavior is added via `impl RaftNode`. The `#[derive(PartialEq, Debug)]` annotation automatically generates equality comparison and debug printing — no boilerplate.

```rust
#[derive(PartialEq, Debug)]
enum NodeState { Follower, Candidate, Leader }
// Comparison: node.state == NodeState::Leader — works with PartialEq derive
```

**Java enum with methods**: Java enums are named constants that can have methods and fields. They work well for state representation. However, they cannot hold per-instance data without awkward workarounds (you cannot have `LEADER(term=4)` as a distinct value; you'd need an enclosing class). Adding behavior requires methods on the enum type, not per-variant data.

```java
enum NodeState { FOLLOWER, CANDIDATE, LEADER }
// Comparison: node.getState() == NodeState.LEADER — works, enums support ==
```

### 7.2 Optional Vote Tracking

**Rust `Option<usize>`**: `voted_for: Option<usize>` is the idiomatic representation of "either has a node ID or has not voted." The compiler forces you to handle both cases before using the value — you cannot dereference `None` without a compile-time error. No null pointer exceptions are possible.

```rust
// Compiler enforces handling:
if let Some(node) = voted_for { /* use node */ }
// or:
voted_for.map(|n| format!("voted for {n}"))
```

**Java `Integer` (boxed)**: `private Integer votedFor` allows `null` to represent "no vote." However, Java's null safety is not compile-time enforced (without annotations like `@NonNull`). Accidentally writing `int x = votedFor` when `votedFor == null` throws a `NullPointerException` at runtime. The safety boundary is the developer's discipline, not the type system.

```java
// Silent NPE risk:
int x = votedFor;  // NullPointerException if votedFor == null
// Correct:
if (votedFor != null) { int x = votedFor; }
```

### 7.3 Term Type: u64 vs long

**Rust `u64`**: unsigned, 64-bit. Range: `0` to `18,446,744,073,709,551,615`. At 1 billion term increments per second, overflow takes ~585 years. The `u64` type self-documents that terms are non-negative.

**Java `long`**: signed, 64-bit. Range: `-2^63` to `2^63 - 1`. Positive range is half of u64 (`~9.2 × 10^18`). At 1 billion term increments per second, the signed overflow would occur after ~292 years — still practically unlimited, but using `long` for a non-negative quantity requires a convention to avoid misinterpretation. Java has no unsigned 64-bit primitive; `Long.compareUnsigned` exists for unsigned comparisons but is rarely used.

### 7.4 Default Immutability

**Rust** bindings are immutable by default. `let node = RaftNode::new(0, 3)` creates an immutable binding. Calling `node.start_election()` (which takes `&mut self`) requires `let mut node = ...`. The compiler enforces this — attempts to mutate an immutable binding are compile-time errors. This pushes you toward correct state management naturally.

**Java** object references are mutable by default. `final RaftNode node = new RaftNode(0, 3)` prevents reassigning `node` to a different object but does not prevent calling `node.startElection()`. The `final` keyword only constrains reference rebinding, not the object's internal state. Immutability of fields requires `private final` per field, and even then, mutable collections (like `HashMap`) within a `final` field can be modified.

### 7.5 State Transition Safety

**Rust**: the `NodeState` enum variants are distinct types that cannot be mixed accidentally. Because `NodeState` does not implement `Copy`, assigning `node.state = NodeState::Leader` moves a new value in — there is no implicit copying or aliasing. Comparing with `==` requires `PartialEq`, which is derived and generated by the compiler, eliminating a whole class of manual equality bugs.

**Java**: the `NodeState` enum values are singletons. Comparing with `==` is safe for Java enums (reference equality is identity equality for enum constants — there is only one `LEADER` instance). However, Java's `switch` statement on enums does not force exhaustive handling in all cases. A `switch` without a `default` case compiles without warning in many configurations, so adding a new enum variant can silently create a code path that is never reached.

Rust's `match` is exhaustive by default — omitting a variant is a compile-time error. This makes Raft state machine code in Rust naturally robust to adding a new state (e.g., `PreCandidate` for the PreVote extension): the compiler immediately flags every unhandled case.

### 7.6 Concurrency Considerations

Neither code snippet in this chapter implements actual concurrent Raft — they simulate state transitions in a single thread. A real Raft implementation adds significant concurrency complexity:

**Rust real-world concurrency**: Raft state that is shared across threads (heartbeat timer, RPC handler, client handler) would use `Arc<Mutex<RaftNode>>` or `Arc<RwLock<RaftNode>>`. Rust's borrow checker prevents data races at compile time — you cannot accidentally access `RaftNode` from two threads without holding the lock. The `Send` and `Sync` marker traits make thread-safety explicit in the type system. Popular Rust Raft libraries: `raft-rs` (used by TiKV, written by PingCAP).

**Java real-world concurrency**: Raft state shared across threads requires `synchronized` blocks or `java.util.concurrent.locks.ReentrantLock`. Java does not enforce this at compile time — accessing `currentTerm` from multiple threads without synchronization compiles fine but produces a data race. The `volatile` keyword provides visibility guarantees for individual fields but not atomicity for compound operations (e.g., `currentTerm++` is not atomic even with `volatile`). Production Java Raft implementations (like etcd's Java client libraries) use explicit locking throughout.

---

## 8. Summary

Raft is the practical answer to the question "how does a distributed system reliably agree on a sequence of values?" Its key contributions:

1. **Understandability as a design constraint**: Raft was designed to be taught and implemented correctly, not to achieve the theoretical minimum message count. This is why it dominates modern distributed systems tooling while Paxos remains primarily academic.

2. **Leader-centric design simplifies reasoning**: all writes flow through one leader per term. There is no ambiguity about which node's value "wins" — the leader's log is authoritative for all uncommitted entries. Once committed (quorum acknowledged), no entry can be lost.

3. **Term-based authority prevents split-brain**: every message carries a term. Stale leaders from previous terms are immediately identified and silenced. A node that was isolated for minutes and then reconnects cannot confuse the cluster — it receives a higher-term heartbeat and steps down.

4. **The election restriction is the safety linchpin**: the rule that a candidate cannot win without a log at least as up-to-date as any voter's log guarantees that all committed entries survive leader transitions. Without this rule, a newly elected leader might overwrite committed entries.

5. **Quorum sizing is the operability lever**: a 3-node cluster tolerates 1 failure. A 5-node cluster tolerates 2 failures and is the standard production configuration. The marginal cost of going from 3 to 5 nodes (one more required ACK per write) is small compared to the doubled fault tolerance.

6. **Multi-Raft enables scale**: a single Raft group is bounded by one leader's throughput. Sharding data across many independent Raft groups (as TiKV and CockroachDB do) scales write throughput linearly with the number of shards.

The implementations above deliberately simplify: there are no RPC calls, no log entries, no timers. The essence — term tracking, vote counting, quorum checks, and state transitions — compiles and runs correctly in both Rust and Java, providing a testable foundation on which a full implementation can be built.

---

*End of Chapter 5.*
