//! Bitcoin data type objects extended with validation context.
//!
//! The data is expected to be prepared in advance and passed as program arguments.
//! The extended set of fields allows to recursively validate entities in a stateless manner,
//! and to avoid repetitive computations.

use raito::utils::Hash;
use raito::test_utils::from_hex;

/// Represents the state of the blockchain.
#[derive(Drop, Copy)]
pub struct ChainState {
    /// Height of the current block.
    pub block_height: Option<u32>,
    /// Total work done.
    pub total_work: u256,
    /// Best block.
    pub best_block_hash: Hash,
    /// Current target.
    pub current_target: u256,
    /// Start of the current epoch.
    pub epoch_start_time: u32,
    /// Previous timestamps.
    pub prev_timestamps: Span<u32>,
    /// Utreexo state.
    pub utreexo_state: UtreexoState,
}

/// Represents the initial state before genesis block.
/// https://github.com/bitcoin/bitcoin/blob/ee367170cb2acf82b6ff8e0ccdbc1cce09730662/src/kernel/chainparams.cpp#L99
impl ChainStateDefault of Default<ChainState> {
    fn default() -> ChainState {
        ChainState {
            block_height: Default::default(),
            total_work: 0,
            best_block_hash: 0_u256.into(),
            current_target: 26959535291011309493156476344723991336010898738574164086137773096960,
            epoch_start_time: 0,
            prev_timestamps: [
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            ].span(), utreexo_state: UtreexoState { roots: [].span() },
        }
    }
}

/// Represents a block in the blockchain.
#[derive(Drop, Copy)]
pub struct Block {
    /// Block header.
    pub header: Header,
    /// Transactions.
    pub txs: Span<Transaction>,
}

/// Represents a block header.
/// https://learnmeabitcoin.com/technical/block/
#[derive(Drop, Copy)]
pub struct Header {
    /// The version of the block.
    pub version: u32,
    /// The timestamp of the block.
    pub time: u32,
    /// The difficulty target for mining the block.
    /// Not strictly necessary since it can be computed from target,
    /// but it is cheaper to validate than compute.
    pub bits: u32,
    /// The nonce used in mining the block.
    pub nonce: u32,
}

/// Represents a transaction.
/// https://learnmeabitcoin.com/technical/transaction/
#[derive(Drop, Copy)]
pub struct Transaction {
    /// The version of the transaction.
    pub version: u32,
    /// Flag which indicates the presence of witness data.
    /// It combines `marker` and `flag` fields for now but in the future
    /// we might need to separate them if transaction structure changes.
    /// Segwit marker and flag do not contribute to TXID (transaction hash),
    /// but do contribute to wTXID.
    pub is_segwit: bool,
    /// The inputs of the transaction.
    pub inputs: Span<TxIn>,
    /// The outputs of the transaction.
    pub outputs: Span<TxOut>,
    /// The lock time of the transaction.
    pub lock_time: u32,
}

/// Represents an input of a transaction.
/// https://learnmeabitcoin.com/technical/transaction/input/
///
/// NOTE that `txid` and `vout` fields can be resolved via Utreexo set using the TXO index.
#[derive(Drop, Copy)]
pub struct TxIn {
    /// The signature script which satisfies the conditions placed in the txo pubkey script
    /// or coinbase script that contains block height (since 227,836) and miner nonce (optional).
    pub script: @ByteArray,
    /// The sequence number of the input.
    pub sequence: u32,
    /// The reference to the previous output that is being used as an input.
    pub previous_output: OutPoint,
    /// The witness data for transactions.
    pub witness: @ByteArray
}

/// Represents a reference to a transaction output.
#[derive(Drop, Copy)]
pub struct OutPoint {
    /// The hash of the referenced transaction.
    pub txid: Hash,
    /// The index of the specific output in the transaction.
    pub vout: u32,
    /// The index of output in the utreexo set (meta field).
    pub txo_index: u64,
    /// Amount calculated with the txid and vout.
    pub amount: u64
}

/// Represents an output of a transaction.
/// https://learnmeabitcoin.com/technical/transaction/output/
#[derive(Drop, Copy)]
pub struct TxOut {
    /// The value of the output in satoshis.
    pub value: u64,
    /// The spending script (aka locking code) for this output.
    pub pk_script: @ByteArray,
}

/// Accumulator representation of the state aka "Compact State Node".
#[derive(Drop, Copy)]
pub struct UtreexoState {
    /// Roots of Merkle tree forest.
    pub roots: Span<felt252>,
}

/// Utreexo set is used to retrieve TXOs spent by particular inputs.
#[derive(Drop, Copy)]
pub struct UtreexoSet {
    /// A list of extended transaction outputs spent in a particular block(s).
    pub outputs: Span<UtreexoOutput>,
}

/// TXO extended with info about parent transaction and the position within it.
/// The hash of this structure is a leaf node in the Utreexo Merkle tree forest.
#[derive(Drop, Copy)]
pub struct UtreexoOutput {
    /// The TXID this output belongs to.
    pub txid: Hash,
    /// The index of this output.
    pub vout: u32,
    /// Output data.
    pub output: TxOut,
}

/// Inclusion proof for multiple leaves.
#[derive(Drop, Copy)]
pub struct UtreexoBatchProof {
    /// Indices of tree leaves, one for each output in the utreexo set.
    pub targets: Span<u64>,
    /// All the nodes required to calculate the root.
    pub proof: Span<felt252>,
}
