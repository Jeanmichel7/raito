use super::utils::{double_sha256, Hash};

pub fn merkle_root(ref hashes: Array<Hash>) -> Hash {
    let len = hashes.len();

    if len == 1 {
        return *hashes.at(0);
    }

    if len % 2 == 1 {
        hashes.append(*hashes.at(len - 1));
    } else {
        // CVE-2012-2459 bug fix
        assert!(
            *hashes.at(len - 1) != *hashes.at(len - 2), "unexpected node duplication in merkle tree"
        );
    }

    let mut next_hashes: Array<Hash> = Default::default();
    let mut i = 0;
    while i < len {
        next_hashes.append(double_sha256(hashes.at(i), hashes.at(i + 1)));
        i += 2;
    };

    merkle_root(ref next_hashes)
}


#[cfg(test)]
mod tests {
    use super::{merkle_root};
    use super::super::utils::{Hash, HashTrait, U256IntoHash};

    #[test]
    #[available_gas(100000000)]
    fn test_merkle_root_01() {
        let mut txids: Array<Hash> = array![
            0xacd9825be8bece7782ec746a80b52f44d6a8af41c63dbab59b03e29558469682_u256.into(),
        ];

        let expected_merkle_root: Hash =
            0xacd9825be8bece7782ec746a80b52f44d6a8af41c63dbab59b03e29558469682_u256
            .into();

        assert_eq!(merkle_root(ref txids), expected_merkle_root);
    }

    #[test]
    #[available_gas(100000000)]
    fn test_merkle_root_02() {
        let mut txids: Array<Hash> = array![
            0x8710b2819a369672a2bce3d5270e7ae0ea59be2f7ce7f9078341b389098953e0_u256.into(),
            0x64efde3a3f3531569cdab031bb31cfeb5c2d8cba62ae1ca5b2913b4ef643fd49_u256.into(),
        ];

        let expected_merkle_root: Hash =
            0x20dadaf81170decafec4b025366b75284dbe31dd42c8da5d25ff62fc4bff5d03_u256
            .into();

        assert_eq!(merkle_root(ref txids), expected_merkle_root);
    }

    #[test]
    #[available_gas(100000000)]
    fn test_merkle_root_03() {
        let mut txids: Array<Hash> = array![
            0x806c0d57e2f14d3111291846f237ab6305d90606822493fea8345d57539da95a_u256.into(),
            0x1089e783a2b275e368c9f7d02ee181604bd98a4418813fc89caa75190d946793_u256.into(),
            0x6f23a5e1667ed4a0abd072288994b2ed593298b06e97bb87acc698d0b369f9b5_u256.into()
        ];

        let expected_merkle_root: Hash =
            0x1350862240c0eaf2fd0bf02e122fe16609d7c5c4f4538f45c0651fdb6ae82a22_u256
            .into();

        assert_eq!(merkle_root(ref txids), expected_merkle_root);
    }

    #[test]
    #[available_gas(100000000)]
    fn test_merkle_root_04() {
        let mut txids = array![
            0xe914f16685930f0430a6fa687b4b17f98f988fe83f0ee26dc162b4cd3f6ea432_u256.into(),
            0x7dd21e3798f3ac7016203db204b0436b8dfb23051192180b5a71150b35fcf96a_u256.into(),
            0x65d02549bb947d23341b39516b4684e8e30f8eca5ba71d7a574d8c57bc8ecf4b_u256.into(),
            0x3d455f551097838265bc64109907b97b6b8a60aae04aed39969047b4ad8a2993_u256.into()
        ];

        let expected_merkle_root =
            0x5545be569eb578bb9498bbc114867edb6259c894370e14f5361988fe07d48b96_u256
            .into();

        assert_eq!(merkle_root(ref txids), expected_merkle_root);
    }

    #[test]
    #[available_gas(100000000)]
    fn test_merkle_root_05() {
        let mut txids = array![
            0xd47e03351ee65f73321b684832edc4c840a1fe4bbd04bdb66a8328e5c7796e21_u256.into(),
            0xbf304002ea77842b32dc91f1efe681a5a7909f4200e658e2ef2beb2a821101b9_u256.into(),
            0x397bdf0bf5a8798f5b10bd95c70bb4a3f42ca14a9a837a4a54cd7de525dc0225_u256.into(),
            0xd6ce148117a1cd094cdd5303ae0896cae1b29ad010b6cb0f3d43fa99b5e2c2f7_u256.into(),
            0x7d5ad03ebf001acb47aafdf4915e86b7368ed3183c1e95f47280d81bb4ef91f8_u256.into(),
            0x69cf63b266ebc862bd4d1a01473703c14bdd3a620f93ec323144c7d2c54529a0_u256.into(),
            0x155be8f959b0187d7528a1ff11b3450690047aa96dbbb29a1ae3832b237c8179_u256.into(),
            0x727d5fbed290d645ced8776c9031d7c3438454b5faf1f5dc0200dbe84f8e6035_u256.into(),
            0xc6056c6021081150a86c092f6785955f757024f41472ad4b0cfd9dd39db8b4a2_u256.into(),
            0x83f26f37bb715ec325f25544b6d7ae920fcc073c146c8dd12fbbde31a7ae1d2f_u256.into(),
            0xd39bc02ef2b2c5afdb7807b0162b573648d9264d5e9872dbf26a7d480de301cd_u256.into(),
            0x3dc087cb9e9d66c4d3e2cf29d23949e7b914db4c3f2114d34f34e97a2a44a169_u256.into(),
            0x497d1b0bf7b0c502043fe7201a9696c466f514de3190097ef3b7d0664fc3d0bf_u256.into(),
            0xa43dbef675b637c554987e8a1b98be3faf8850f88fa1bdf59b124c2356135a33_u256.into(),
            0x4f9cf2c386b34b01d48a01ea31b5c795d1e869b42de78410b3ea1adf658f62a2_u256.into(),
            0x46ef4071d3ddfd9443361ef2f4b2d5da7c57eaf59785564782d0d9b95280cb9b_u256.into(),
            0xa48c60d6b27fd5c662d7dcd248b528474fd2598d26d51525deea3d225d7260e0_u256.into(),
            0x5bb6e10378329bf6e78ce3e0f3abae1fb1c4bc40e1ce1b0e1a5f5db8a7fb1897_u256.into(),
        ];

        let expected_merkle_root: Hash =
            0xe1455aa624aa92fa8b52766199033d66e4d100b39029e69906ae594397d977af_u256
            .into();

        assert_eq!(merkle_root(ref txids), expected_merkle_root);
    }

    #[test]
    #[available_gas(100000000)]
    fn test_merkle_root_05_bis() {
        let mut txids = array![
            HashTrait::to_hash(
                [
                    0xd47e0335,
                    0x1ee65f73,
                    0x321b6848,
                    0x32edc4c8,
                    0x40a1fe4b,
                    0xbd04bdb6,
                    0x6a8328e5,
                    0xc7796e21
                ]
            ),
            HashTrait::to_hash(
                [
                    0xbf304002,
                    0xea77842b,
                    0x32dc91f1,
                    0xefe681a5,
                    0xa7909f42,
                    0x00e658e2,
                    0xef2beb2a,
                    0x821101b9
                ]
            ),
            HashTrait::to_hash(
                [
                    0x397bdf0b,
                    0xf5a8798f,
                    0x5b10bd95,
                    0xc70bb4a3,
                    0xf42ca14a,
                    0x9a837a4a,
                    0x54cd7de5,
                    0x25dc0225
                ]
            ),
            HashTrait::to_hash(
                [
                    0xd6ce1481,
                    0x17a1cd09,
                    0x4cdd5303,
                    0xae0896ca,
                    0xe1b29ad0,
                    0x10b6cb0f,
                    0x3d43fa99,
                    0xb5e2c2f7
                ]
            ),
            HashTrait::to_hash(
                [
                    0x7d5ad03e,
                    0xbf001acb,
                    0x47aafdf4,
                    0x915e86b7,
                    0x368ed318,
                    0x3c1e95f4,
                    0x7280d81b,
                    0xb4ef91f8
                ]
            ),
            HashTrait::to_hash(
                [
                    0x69cf63b2,
                    0x66ebc862,
                    0xbd4d1a01,
                    0x473703c1,
                    0x4bdd3a62,
                    0x0f93ec32,
                    0x3144c7d2,
                    0xc54529a0
                ]
            ),
            HashTrait::to_hash(
                [
                    0x155be8f9,
                    0x59b0187d,
                    0x7528a1ff,
                    0x11b34506,
                    0x90047aa9,
                    0x6dbbb29a,
                    0x1ae3832b,
                    0x237c8179
                ]
            ),
            HashTrait::to_hash(
                [
                    0x727d5fbe,
                    0xd290d645,
                    0xced8776c,
                    0x9031d7c3,
                    0x438454b5,
                    0xfaf1f5dc,
                    0x0200dbe8,
                    0x4f8e6035
                ]
            ),
            HashTrait::to_hash(
                [
                    0xc6056c60,
                    0x21081150,
                    0xa86c092f,
                    0x6785955f,
                    0x757024f4,
                    0x1472ad4b,
                    0x0cfd9dd3,
                    0x9db8b4a2
                ]
            ),
            HashTrait::to_hash(
                [
                    0x83f26f37,
                    0xbb715ec3,
                    0x25f25544,
                    0xb6d7ae92,
                    0x0fcc073c,
                    0x146c8dd1,
                    0x2fbbde31,
                    0xa7ae1d2f
                ]
            ),
            HashTrait::to_hash(
                [
                    0xd39bc02e,
                    0xf2b2c5af,
                    0xdb7807b0,
                    0x162b5736,
                    0x48d9264d,
                    0x5e9872db,
                    0xf26a7d48,
                    0x0de301cd
                ]
            ),
            HashTrait::to_hash(
                [
                    0x3dc087cb,
                    0x9e9d66c4,
                    0xd3e2cf29,
                    0xd23949e7,
                    0xb914db4c,
                    0x3f2114d3,
                    0x4f34e97a,
                    0x2a44a169
                ]
            ),
            HashTrait::to_hash(
                [
                    0x497d1b0b,
                    0xf7b0c502,
                    0x043fe720,
                    0x1a9696c4,
                    0x66f514de,
                    0x3190097e,
                    0xf3b7d066,
                    0x4fc3d0bf
                ]
            ),
            HashTrait::to_hash(
                [
                    0xa43dbef6,
                    0x75b637c5,
                    0x54987e8a,
                    0x1b98be3f,
                    0xaf8850f8,
                    0x8fa1bdf5,
                    0x9b124c23,
                    0x56135a33
                ]
            ),
            HashTrait::to_hash(
                [
                    0x4f9cf2c3,
                    0x86b34b01,
                    0xd48a01ea,
                    0x31b5c795,
                    0xd1e869b4,
                    0x2de78410,
                    0xb3ea1adf,
                    0x658f62a2
                ]
            ),
            HashTrait::to_hash(
                [
                    0x46ef4071,
                    0xd3ddfd94,
                    0x43361ef2,
                    0xf4b2d5da,
                    0x7c57eaf5,
                    0x97855647,
                    0x82d0d9b9,
                    0x5280cb9b
                ]
            ),
            HashTrait::to_hash(
                [
                    0xa48c60d6,
                    0xb27fd5c6,
                    0x62d7dcd2,
                    0x48b52847,
                    0x4fd2598d,
                    0x26d51525,
                    0xdeea3d22,
                    0x5d7260e0
                ]
            ),
            HashTrait::to_hash(
                [
                    0x5bb6e103,
                    0x78329bf6,
                    0xe78ce3e0,
                    0xf3abae1f,
                    0xb1c4bc40,
                    0xe1ce1b0e,
                    0x1a5f5db8,
                    0xa7fb1897
                ]
            ),
        ];

        let expected_merkle_root: Hash =
            0xe1455aa624aa92fa8b52766199033d66e4d100b39029e69906ae594397d977af_u256
            .into();

        assert_eq!(merkle_root(ref txids), expected_merkle_root);
    }
}

