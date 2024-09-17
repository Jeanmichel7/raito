//! Utreexo is an accumulator for the Bitcoin unspent transaction set.
//!
//! It allows to verify that a certain transaction output exists
//! and still unspent at a particular block while maintaining only
//! a very compact state.
//!
//! It is also useful for transaction validation (our case) since it
//! allows to "fetch" the output spent by a particular input in the
//! validated transaction. This is typically required to calculate
//! transaction fee and also to check that script execution succeeds.
//!
//! The expected workflow is the following:
//!   - For coinbase and inputs spending TXOs created in the same block
//!     utreexo accumulator is not updated (local cache is used instead);
//!   - For all other inputs we provide respective TXOs (extended) plus
//!     plus inclusion proof (can be individual, batched, or hybrid);
//!   - The client has to verify the inclusion proof and then remove all
//!     the TXOs from the utreexo set, that way updating the state;
//!   - For every output that is not spent in the same block we add the
//!     extended (additionally contains txid and output index aka vout) output
//!     to the accumulator (i.e. update the utreexo state).
//!
//! Note that utreexo data and proofs are provided via program input so
//! it is not part of prover/verifier arguments. Utreexo state (which
//! is part of the chain state) is what allows us to constrain
//! these inputs and ensure integrity.
//!
//! Read more about utreexo: https://eprint.iacr.org/2019/611.pdf

use super::transaction::OutPoint;
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use core::fmt::{Display, Formatter, Error};
use utils::hash::Digest;

/// Accumulator representation of the state aka "Compact State Node".
/// Part of the chain state.
#[derive(Drop, Copy, PartialEq, Serde, Debug)]
pub struct UtreexoState {
    /// Roots of the Merkle tree forest.
    /// Index is the root height, None means a gap.
    pub roots: Span<Option<felt252>>,
    /// Total number of leaves (in the bottom-most row).
    /// Required to calculate the number of nodes in a particular row.
    /// Can be reconstructed from the roots, but cached for convenience.
    pub num_leaves: u64,
}

/// Accumulator interface
pub trait UtreexoAccumulator {
    /// Adds single output to the accumulator.
    /// The order *is important*: adding A,B and B,A would result in different states.
    ///
    /// Note that this call also pushes old UTXOs "to the left", to a larger subtree.
    /// This mechanism ensures that short-lived outputs have small inclusion proofs.
    fn add(ref self: UtreexoState, outpoint_hash: felt252);

    /// Verifies inclusion proof for a single output.
    fn verify(
        self: @UtreexoState, output: @OutPoint, proof: @UtreexoProof
    ) -> Result<(), UtreexoError>;

    /// Removes single output from the accumlator (order is important).
    ///
    /// Note that once verified, the output itself is not required for deletion,
    /// the leaf index plus inclusion proof is enough.
    fn delete(ref self: UtreexoState, proof: @UtreexoProof);

    /// Verifies batch proof for multiple outputs (e.g. all outputs in a block).
    fn verify_batch(
        self: @UtreexoState, outputs: Span<OutPoint>, proof: @UtreexoBatchProof
    ) -> Result<(), UtreexoError>;

    /// Removes multiple outputs from the accumulator.
    fn delete_batch(ref self: UtreexoState, proof: @UtreexoBatchProof);
}

// https://eprint.iacr.org/2019/611.pdf Algorithm 1 AddOne
// p18
// To prevent such an attack, we require that the data inserted into the
// accumulator be not just the hash of a TXO, which is controllable by the
// attacker, but instead the concatenation of the TXO data with the block
// hash in which the TXO is confirmed. The attacker does not know the block
// hash before the TXO is confirmed, and it is not alterable by the attacker
// after confirmation (without significant cost). Verifiers, when inserting into
// the accumulator, perform this concatenation themselves after checking the
// proof of work of the block. Inclusion proofs contain this block hash data so
// that the leaf hash value can be correctly computed.
fn parent_hash(left: felt252, right: felt252, _block_hash: Digest) -> felt252 {
    let parent_data = (left, right);
    PoseidonTrait::new().update_with(parent_data).finalize()
}

pub impl UtreexoAccumulatorImpl of UtreexoAccumulator {
    // https://eprint.iacr.org/2019/611.pdf Algorithm 1 AddOne
    fn add(ref self: UtreexoState, outpoint_hash: felt252) {
        let mut new_roots: Array<Option<felt252>> = Default::default();
        let mut n: felt252 = outpoint_hash;
        let mut first_none_found: bool = false;

        for root in self
            .roots {
                if (!first_none_found) {
                    if (root.is_none()) {
                        first_none_found = true;
                        new_roots.append(Option::Some(n));
                    } else {
                        n = parent_hash((*root).unwrap(), n, 0x0_u256.into());
                        new_roots.append(Option::None);
                    }
                } else {
                    new_roots.append(*root);
                }
            };

        //check if end with Option::None
        if (new_roots[new_roots.len() - 1].is_some()) {
            new_roots.append(Option::None);
        }

        self.roots = new_roots.span();
        self.num_leaves += 1_u64;
    }

    fn verify(
        self: @UtreexoState, output: @OutPoint, proof: @UtreexoProof
    ) -> Result<(), UtreexoError> {
        Result::Ok(())
    }

    fn delete(ref self: UtreexoState, proof: @UtreexoProof) {}

    fn verify_batch(
        self: @UtreexoState, outputs: Span<OutPoint>, proof: @UtreexoBatchProof
    ) -> Result<(), UtreexoError> {
        Result::Ok(())
    }

    fn delete_batch(ref self: UtreexoState, proof: @UtreexoBatchProof) {}
}

#[derive(Drop, Copy, PartialEq)]
pub enum UtreexoError {}

/// Utreexo inclusion proof for a single transaction output.
#[derive(Drop, Copy)]
pub struct UtreexoProof {
    /// Index of the leaf in the forest, but also an encoded binary path,
    /// specifying which sibling node is left and which is right.
    pub leaf_index: u64,
    /// List of sibling nodes required to calculate the root.
    pub proof: Span<felt252>,
}

/// Utreexo inclusion proof for multiple outputs.
/// Compatible with https://github.com/utreexo/utreexo
#[derive(Drop, Copy)]
pub struct UtreexoBatchProof {
    /// Indices of leaves to be deleted (ordered starting from 0, left to right).
    pub targets: Span<u64>,
    /// List of sibling nodes required to calculate the root.
    pub proof: Span<felt252>,
}

pub impl UtreexoStateDefault of Default<UtreexoState> {
    fn default() -> UtreexoState {
        UtreexoState { roots: array![Option::None].span(), num_leaves: 0, }
    }
}

impl UtreexoStateDisplay of Display<UtreexoState> {
    fn fmt(self: @UtreexoState, ref f: Formatter) -> Result<(), Error> {
        let str: ByteArray = format!(
            "UtreexoState {{ roots: {}, num_leaves: {}, }}", (*self.roots).len(), *self.num_leaves
        );
        f.buffer.append(@str);
        Result::Ok(())
    }
}

impl UtreexoProofDisplay of Display<UtreexoProof> {
    fn fmt(self: @UtreexoProof, ref f: Formatter) -> Result<(), Error> {
        let mut proofs: ByteArray = Default::default();
        for proof in *self.proof {
            proofs.append(@format!("{},", proof));
        };
        let str: ByteArray = format!(
            "UtreexoProof {{ leaf_index: {}, proof: {}, }}", *self.leaf_index, @proofs
        );
        f.buffer.append(@str);
        Result::Ok(())
    }
}

impl UtreexoBatchProofDisplay of Display<UtreexoBatchProof> {
    fn fmt(self: @UtreexoBatchProof, ref f: Formatter) -> Result<(), Error> {
        let mut targets: ByteArray = Default::default();
        let mut proofs: ByteArray = Default::default();
        for target in *self.targets {
            targets.append(@format!("{},", target));
        };
        for proof in *self.proof {
            proofs.append(@format!("{},", proof));
        };
        let str: ByteArray = format!(
            "UtreexoBatchProof {{ leaf_index: [{}], proof: [{}] }}", @targets, @proofs
        );
        f.buffer.append(@str);
        Result::Ok(())
    }
}
