from utreexo import Utreexo
from poseidon_py.poseidon_hash import poseidon_hash_many


class TxOut:
    def __init__(self, value, pk_script, cached):
        self.value = value
        self.pk_script = pk_script
        self.cached = cached

    def serialize(self):
        res = []
        res.append(self.value)

        data = []
        sub_data = []
        pending_word = 0
        pending_word_len = 0

        # Convert `pk_script` to bytes
        if self.pk_script.startswith("0x") or self.pk_script.startswith("0X"):
            hex_str = self.pk_script[2:]
            byte_data = bytes.fromhex(hex_str)
        else:
            byte_data = self.pk_script.encode("utf-8")

        for byte in byte_data:
            if not (0 <= byte <= 255):
                raise ValueError("Not between 0 and 255.")

            if pending_word_len == 0:
                pending_word = byte
                pending_word_len = 1
                continue

            new_pending = pending_word * 0x100 + byte
            if pending_word_len < 31 - 1:
                pending_word = new_pending
                pending_word_len += 1
                continue

            # Convert new_pending to 31 bytes (big endian)
            new_pending_bytes = new_pending.to_bytes(31, byteorder="big")
            word_int = int.from_bytes(new_pending_bytes, "big")
            sub_data.append(word_int)

            pending_word = 0
            pending_word_len = 0

        data.append(len(sub_data))
        data.extend(sub_data)

        # Check if there's still a word pending
        if pending_word_len > 0:
            data.append(pending_word)
        data.append(pending_word_len)

        # Add pk_script serialized
        res.extend(data)
        res.append(1 if self.cached else 0)

        return res

    def __repr__(self):
        return f"TxOut(\n\
                    value={self.value}\n\
                    pk_script={self.pk_script}\n\
                    cached={self.cached})"


class OutPoint:
    def __init__(
        self, txid, vout, data, block_height, block_time, block_hash, is_coinbase
    ):
        self.txid = txid
        self.vout = vout
        self.data = data  # Instance de TxOut
        self.block_height = block_height
        self.block_time = block_time
        self.block_hash = block_hash
        self.is_coinbase = is_coinbase

    def hash(self):
        tab = []

        # txid (2x u128 in little endian high/low)
        txid_bytes = bytes.fromhex(self.txid)
        tab.append(int.from_bytes(txid_bytes[:16], "little"))
        tab.append(int.from_bytes(txid_bytes[16:], "little"))

        # vout
        tab.append(self.vout)

        # prev output
        for e in self.data.serialize():
            tab.append(e)

        # block hash (2x u128 in little endian high/low)
        txid_bytes = bytes.fromhex(self.block_hash)
        tab.append(int.from_bytes(txid_bytes[:16], "little"))
        tab.append(int.from_bytes(txid_bytes[16:], "little"))

        tab.append(self.block_height)
        tab.append(self.block_time)

        tab.append(int(self.is_coinbase))

        hash = poseidon_hash_many(tab)
        return hash

    def __repr__(self):
        return f"OutPoint(\n\
                txid={self.txid}\n\
                vout={self.vout}\n\
                tx_out={self.data}\n\
                block_height={self.block_height}\n\
                block_time={self.block_time}\n\
                block_hash={self.block_hash}\n\
                is_coinbase={self.is_coinbase})"


class UtreexoData:
    def __init__(self) -> None:
        self.utreexo = Utreexo()

    def snapshot_state(self) -> dict:
        return {
            "roots": list(map(format_root_node, self.utreexo.root_nodes)),
            "num_leaves": len(self.utreexo.leaf_nodes),
        }

    def apply_blocks(self, blocks: list) -> dict:
        state = {}
        proofs = []
        for block_idx, block in enumerate(blocks):
            if block_idx == len(blocks) - 1:
                state = self.snapshot_state()

            # First we remove all STXOs
            for i, (txid, tx) in enumerate(block["data"].items()):
                # Skip coinbase tx input
                if i != 0:
                    inc_proofs = self.handle_txin(tx["inputs"])
                    # Storing proofs for last block only
                    if block_idx == len(blocks) - 1:
                        proofs.extend(inc_proofs)

            # Then we add all new UTXOs
            for i, (txid, tx) in enumerate(block["data"].items()):
                self.handle_txout(
                    tx["outputs"],
                    block["hash"],
                    block["height"],
                    block["time"],
                    txid,
                    i == 0,
                )
        return {"state": state, "proofs": proofs, "expected": self.snapshot_state()}

    def handle_txin(self, inputs: list) -> list:
        proofs = []
        for input in inputs:
            outpoint = input["previous_output"]

            # Skip if output is cached
            if outpoint["data"]["cached"]:
                continue

            outpoint = OutPoint(
                txid=outpoint["txid"],
                vout=outpoint["vout"],
                data=TxOut(
                    value=outpoint["data"]["value"],
                    pk_script=outpoint["data"]["pk_script"],
                    cached=outpoint["data"]["cached"],
                ),
                block_height=outpoint["block_height"],
                block_time=outpoint["block_time"],
                block_hash=outpoint["block_hash"],
                is_coinbase=outpoint["is_coinbase"],
            )

            # Remove OutPoint from accumulator and get proof
            proof, leaf_index = self.utreexo.delete(outpoint.hash())
            proofs.append(
                {"proof": list(map(format_node, proof)), "leaf_index": leaf_index}
            )

        return proofs

    def handle_txout(
        self,
        outputs: list,
        block_hash: str,
        block_height: int,
        block_time: int,
        txid: str,
        is_coinbase: bool,
    ):
        for i, output in enumerate(outputs):
            # Skip if output is cached
            if output["cached"]:
                continue

            new_outpoint = OutPoint(
                txid=txid,
                vout=i,
                data=TxOut(
                    value=output["value"],
                    pk_script=output["pk_script"],
                    cached=output["cached"],
                ),
                block_height=block_height,
                block_time=block_time,
                block_hash=block_hash,
                is_coinbase=is_coinbase,
            )

            # Add OutPoint to accumulator
            self.utreexo.add(new_outpoint.hash())


def format_root_node(node) -> str:
    if node:
        return {"variant_id": 0, "value": format_node(node)}
    else:
        return None


def format_node(node) -> int:
    return int.from_bytes(bytes.fromhex(node.val[2:]), "big")
