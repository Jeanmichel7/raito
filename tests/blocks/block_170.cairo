// THIS CODE IS GENERATED BY SCRIPT, DO NOT EDIT IT MANUALLY

use raito::types::transaction::{Transaction, TxIn, TxOut, OutPoint};
use raito::types::block::{Block, Header};
use raito::utils::hex::from_hex;
use raito::utils::hash::Hash;

// block_hash: 00000000d1145790a8694403d4063f323d499e655c83426834d4ce2f8dd4a2ee
pub fn block_170() -> Block {
    Block {
        header: Header {
            version: 1_u32, time: 1231731025_u32, bits: 486604799_u32, nonce: 1889418792_u32,
        },
        txs: array![
            Transaction {
                version: 1,
                is_segwit: false,
                lock_time: 0,
                inputs: array![
                    TxIn {
                        script: @from_hex("04ffff001d0102"),
                        sequence: 4294967295,
                        witness: array![].span(),
                        previous_output: OutPoint {
                            txid: 0_u256.into(),
                            vout: 0xffffffff_u32,
                            data: Default::default(),
                            block_height: Default::default(),
                            block_time: Default::default(),
                        },
                    }
                ]
                    .span(),
                outputs: array![
                    TxOut {
                        value: 5000000000_u64,
                        pk_script: @from_hex(
                            "4104d46c4968bde02899d2aa0963367c7a6ce34eec332b32e42e5f3407e052d64ac625da6f0718e7b302140434bd725706957c092db53805b821a85b23a7ac61725bac"
                        ),
                        cached: false,
                    },
                ]
                    .span(),
            },
            Transaction {
                version: 1,
                is_segwit: false,
                lock_time: 0,
                inputs: array![
                    TxIn {
                        script: @from_hex(
                            "47304402204e45e16932b8af514961a1d3a1a25fdf3f4f7732e9d624c6c61548ab5fb8cd410220181522ec8eca07de4860a4acdd12909d831cc56cbbac4622082221a8768d1d0901"
                        ),
                        sequence: 4294967295,
                        witness: array![].span(),
                        previous_output: OutPoint {
                            //TODO reverse order from RPC
                            txid: 0xc997a5e56e104102fa209c6a852dd90660a20b2d9c352423edce25857fcd3704_u256
                                .into(), // use txid as little endian 
                            vout: 0_u32,
                            data: TxOut {
                                value: 5000000000_u64,
                                pk_script: @from_hex(
                                    "410411db93e1dcdb8a016b49840f8c53bc1eb68a382e97b1482ecad7b148a6909a5cb2e0eaddfb84ccf9744464f82e160bfa9b8b64f9d4c03f999b8643f656b412a3ac"
                                ),
                                cached: false,
                            },
                            block_height: 9_u32,
                            block_time: 1231473279_u32,
                        },
                    },
                ]
                    .span(),
                outputs: array![
                    TxOut {
                        value: 1000000000_u64,
                        pk_script: @from_hex(
                            "4104ae1a62fe09c5f51b13905f07f06b99a2f7159b2225f374cd378d71302fa28414e7aab37397f554a7df5f142c21c1b7303b8a0626f1baded5c72a704f7e6cd84cac"
                        ),
                        cached: false,
                    },
                    TxOut {
                        value: 4000000000_u64,
                        pk_script: @from_hex(
                            "410411db93e1dcdb8a016b49840f8c53bc1eb68a382e97b1482ecad7b148a6909a5cb2e0eaddfb84ccf9744464f82e160bfa9b8b64f9d4c03f999b8643f656b412a3ac"
                        ),
                        cached: false,
                    },
                ]
                    .span(),
            },
        ]
            .span(),
    }
}
