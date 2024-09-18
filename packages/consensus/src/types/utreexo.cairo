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
                        n = PoseidonTrait::new().update_with(((*root).unwrap(), n)).finalize();
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


#[cfg(test)]
mod tests {
    use consensus::types::utxo_set::{UtxoSet, UtxoSetTrait};

    #[test]
    /// To check the validity of expected fields, there is a python program from ZeroSync
    /// https://github.com/ZeroSync/ZeroSync/blob/main/src/utxo_set/bridge_node.py
    /// $ python scripts/data/utreexo.py
    fn test_utreexo_add1() {
        let mut utxo_set: UtxoSet = UtxoSetTrait::new(Default::default());
        let outpoint: felt252 = 0x291F8F5FC449D42C715B529E542F24A80136D18F4A85DE28829CD3DCAAC1B9C;

        // add first leave to empty utreexo
        utxo_set.leaves_to_add = array![outpoint];
        utxo_set.utreexo_add();

        let expected: Span<Option<felt252>> = array![
            Option::Some(0x291F8F5FC449D42C715B529E542F24A80136D18F4A85DE28829CD3DCAAC1B9C),
            Option::None
        ]
            .span();
        assert_eq!(utxo_set.utreexo_state.roots, expected, "cannot add first leave");
        assert_eq!(utxo_set.utreexo_state.num_leaves, 1);

        // add second leave
        utxo_set.leaves_to_add = array![outpoint];
        utxo_set.utreexo_add();

        let expected: Span<Option<felt252>> = array![
            Option::None,
            Option::Some(0x738A7C495E564574993BBCB6A62D65C3C570BB81C63801066AF8934649F66F6),
            Option::None
        ]
            .span();
        assert_eq!(utxo_set.utreexo_state.roots, expected, "cannot add second leave");
        assert_eq!(utxo_set.utreexo_state.num_leaves, 2);

        // add thirdth leave
        utxo_set.leaves_to_add = array![outpoint];
        utxo_set.utreexo_add();

        let expected: Span<Option<felt252>> = array![
            Option::Some(0x291F8F5FC449D42C715B529E542F24A80136D18F4A85DE28829CD3DCAAC1B9C),
            Option::Some(0x738A7C495E564574993BBCB6A62D65C3C570BB81C63801066AF8934649F66F6),
            Option::None
        ]
            .span();
        assert_eq!(utxo_set.utreexo_state.roots, expected, "cannot add thirdth leave");
        assert_eq!(utxo_set.utreexo_state.num_leaves, 3);

        // add fourth leave
        utxo_set.leaves_to_add = array![outpoint];
        utxo_set.utreexo_add();

        let expected: Span<Option<felt252>> = array![
            Option::None,
            Option::None,
            Option::Some(0x25D0DE35DD446E3D35504866FD7A04D4245E01B5908E19EAA70ABA84DD5A1F1),
            Option::None
        ]
            .span();
        assert_eq!(utxo_set.utreexo_state.roots, expected, "cannot add fourth leave");
        assert_eq!(utxo_set.utreexo_state.num_leaves, 4);

        // add fifth leave
        utxo_set.leaves_to_add = array![outpoint];
        utxo_set.utreexo_add();

        let expected: Span<Option<felt252>> = array![
            Option::Some(0x291F8F5FC449D42C715B529E542F24A80136D18F4A85DE28829CD3DCAAC1B9C),
            Option::None,
            Option::Some(0x25D0DE35DD446E3D35504866FD7A04D4245E01B5908E19EAA70ABA84DD5A1F1),
            Option::None
        ]
            .span();
        assert_eq!(utxo_set.utreexo_state.roots, expected, "cannot add fifth leave");
        assert_eq!(utxo_set.utreexo_state.num_leaves, 5);

        // add 3 leaves
        utxo_set.leaves_to_add = array![outpoint, outpoint, outpoint];
        utxo_set.utreexo_add();

        let expected: Span<Option<felt252>> = array![
            Option::None,
            Option::None,
            Option::None,
            Option::Some(0x708EB39E30B035376EC871F8F17CD3BADAE6A68406B13C3BB671009D56F5AD),
            Option::None
        ]
            .span();
        assert_eq!(utxo_set.utreexo_state.roots, expected, "cannot add 3 leaves");
        assert_eq!(utxo_set.utreexo_state.num_leaves, 8);

        // add 22 leaves
        utxo_set
            .leaves_to_add =
                array![
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint,
                    outpoint
                ];
        utxo_set.utreexo_add();

        let expected: Span<Option<felt252>> = [
            Option::None(()),
            Option::Some(0x738A7C495E564574993BBCB6A62D65C3C570BB81C63801066AF8934649F66F6),
            Option::Some(0x25D0DE35DD446E3D35504866FD7A04D4245E01B5908E19EAA70ABA84DD5A1F1),
            Option::Some(0x708EB39E30B035376EC871F8F17CD3BADAE6A68406B13C3BB671009D56F5AD),
            Option::Some(0x58D6BEF6CFC28638FB4C8271355961F50922BCC1577DD2B6D04E11B7A911702),
            Option::None(())
        ].span();
        assert_eq!(utxo_set.utreexo_state.roots, expected, "cannot add 22 leaves");
        assert_eq!(utxo_set.utreexo_state.num_leaves, 30);
    }
    ///
/// python scripts/data/utreexo.py
///
/// Roots:
/// ['0x0291f8f5fc449d42c715b529e542f24a80136d18f4a85de28829cd3dcaac1b9c', '', '', '', '', '',
/// '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
///
/// Roots:
/// ['', '0x0738a7c495e564574993bbcb6a62d65c3c570bb81c63801066af8934649f66f6', '', '', '', '',
/// '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
///
/// Roots: ['0x0291f8f5fc449d42c715b529e542f24a80136d18f4a85de28829cd3dcaac1b9c',
/// '0x0738a7c495e564574993bbcb6a62d65c3c570bb81c63801066af8934649f66f6', '', '', '', '', '',
/// '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
///
/// Roots: ['', '', '0x025d0de35dd446e3d35504866fd7a04d4245e01b5908e19eaa70aba84dd5a1f1', '',
/// '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
///
/// Roots: ['0x0291f8f5fc449d42c715b529e542f24a80136d18f4a85de28829cd3dcaac1b9c', '',
/// '0x025d0de35dd446e3d35504866fd7a04d4245e01b5908e19eaa70aba84dd5a1f1', '', '', '', '', '',
/// '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
///
/// Roots: ['', '', '', '0x00708eb39e30b035376ec871f8f17cd3badae6a68406b13c3bb671009d56f5ad',
/// '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
///
/// Roots: ['', '0x0738a7c495e564574993bbcb6a62d65c3c570bb81c63801066af8934649f66f6',
/// '0x025d0de35dd446e3d35504866fd7a04d4245e01b5908e19eaa70aba84dd5a1f1',
/// '0x00708eb39e30b035376ec871f8f17cd3badae6a68406b13c3bb671009d56f5ad',
/// '0x058d6bef6cfc28638fb4c8271355961f50922bcc1577dd2b6d04e11b7a911702', '', '', '', '', '',
/// '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
}
