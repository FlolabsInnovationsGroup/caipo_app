"""R03 framing for the laptop CAIPO peripheral. Little-endian. Opcode 0 is reserved."""

import struct

OPCODE_REQUEST = 0x01
OPCODE_READY = 0x02
OPCODE_METADATA = 0x03
OPCODE_CHUNK = 0x04
OPCODE_ACK = 0x05
OPCODE_ERROR = 0x06
OPCODE_HEARTBEAT = 0x10

CONTENT_AUDIO = 0x01
MAX_CHUNK = 502


def crc32(data: bytes) -> int:
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


def handshake(opcode: int, transfer_id: int) -> bytes:
    return struct.pack("<BH", opcode, transfer_id & 0xFFFF)


def metadata(transfer_id: int, total_size: int, content_type: int, digest: int, chunk_count: int) -> bytes:
    return b"".join(
        (
            struct.pack("<BH", OPCODE_METADATA, transfer_id & 0xFFFF),
            struct.pack("<I", total_size & 0xFFFFFFFF),
            struct.pack("<B", content_type & 0xFF),
            struct.pack("<I", digest & 0xFFFFFFFF),
            struct.pack("<H", chunk_count & 0xFFFF),
        )
    )


def chunk(transfer_id: int, sequence: int, payload: bytes) -> bytes:
    if len(payload) > MAX_CHUNK:
        raise ValueError("payload longer than 502")
    return struct.pack("<BHHH", OPCODE_CHUNK, transfer_id, sequence, len(payload)) + payload


def heartbeat(counter: int) -> bytes:
    return bytes((OPCODE_HEARTBEAT, counter & 0xFF))


def decode(frame: bytes):
    if not frame or frame[0] == 0:
        return None
    opcode = frame[0]
    if opcode in (OPCODE_REQUEST, OPCODE_READY, OPCODE_ACK) and len(frame) == 3:
        return {"opcode": opcode, "transfer_id": struct.unpack_from("<H", frame, 1)[0]}
    if opcode == OPCODE_METADATA and len(frame) == 14:
        transfer_id, total_size = struct.unpack_from("<HI", frame, 1)
        content_type = frame[7]
        digest = struct.unpack_from("<I", frame, 8)[0]
        count = struct.unpack_from("<H", frame, 12)[0]
        return {
            "opcode": opcode,
            "transfer_id": transfer_id,
            "total_size": total_size,
            "content_type": content_type,
            "crc32": digest,
            "chunk_count": count,
        }
    if opcode == OPCODE_CHUNK and len(frame) >= 7:
        transfer_id, sequence, length = struct.unpack_from("<HHH", frame, 1)
        if length != len(frame) - 7 or length > MAX_CHUNK:
            return None
        return {"opcode": opcode, "transfer_id": transfer_id, "sequence": sequence, "payload": frame[7:]}
    if opcode == OPCODE_ERROR and len(frame) == 6:
        transfer_id, code, sequence = struct.unpack_from("<HBH", frame, 1)
        return {"opcode": opcode, "transfer_id": transfer_id, "code": code, "sequence": sequence}
    if opcode == OPCODE_HEARTBEAT and len(frame) == 2:
        return {"opcode": opcode, "counter": frame[1]}
    return None
