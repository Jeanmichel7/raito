def txin_coinbase:
    "TxIn {
        script: @from_hex(\"\(.coinbase)\"),
        sequence: \(.sequence),
        previous_output: OutPoint {
            txid: 0x\(0)_u256.into(),
            vout: 0xffffffff_u32,
            txo_index: 0, 
            amount: 0 
        },
        witness: LITERAL_AT_QUOTES
    }"
;

def txin_regular:
    "TxIn {
        script: @from_hex(\"\(.scriptSig.hex)\"),
        sequence: \(.sequence),
        previous_output: OutPoint {
            txid: 0x\(.txid)_u256.into(),
            vout: \(.vout),
            txo_index: 0, // TODO: implement
            amount: 0 // TODO: implement
        },
        witness: LITERAL_AT_QUOTES
    }"
;

def txin:
    if .coinbase then
        txin_coinbase
    else
        txin_regular
    end
;

def txout:
    "TxOut {
        value: \((.value*100000000) | round)_u64,
        pk_script: @from_hex(\"\(.scriptPubKey.hex)\"),
    }"
;

def tx:
    "Transaction {
        version: \(.version),
        is_segwit: false,
        inputs: array![\(.vin | map(txin) | join(",\n"))].span(),
        outputs: array![\(.vout | map(txout) | join(",\n"))].span(),
        lock_time: \(.locktime)
    }"
;

def block:
    "Block {
        header : Header {	
            version: \(.version)_u32,
            time: \(.time)_u32,
            bits: 0, // TODO
            nonce: \(.nonce)_u32
        },
		txs: array![\(.tx | map(tx) | join(",\n"))].span()
   }"
;

def chain_state:
    "ChainState {
        block_height: \(.prev_block.height)_u32,
        total_work: \(.prev_block.chainwork)_u256, 
        best_block_hash: 0x\(.prev_block.hash)_u256.into(),
        current_target: 0x\(.prev_block.bits)_u256, 
        epoch_start_time: \(.prev_block.time)_u32, 
        prev_timestamps: array![\(.prev_block.prev_timestamps | join(", "))].span(), 
        utreexo_state: UtreexoState { roots: array![].span() },
    }"
;


def fixture:
"use raito::state::{Block, Header, Transaction, OutPoint, TxIn, TxOut, ChainState, UtreexoState};
use raito::test_utils::from_hex;

pub fn block_\(.height)() -> Block {
    // block hash: \(.hash)
     \( . | block )
}"

pub fn chain_state_for_block_\(.height)() -> ChainState {
    // State for block \(.height - 1)
    \( . | chain_state )
}"
;

.result | fixture

