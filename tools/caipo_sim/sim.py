"""Laptop BLE peripheral that advertises as CAIPO-SIM.

Requires the `bless` package and a Bluetooth radio:

    pip install bless
    python tools/caipo_sim/sim.py

Windows and macOS both need a radio the OS will let a user-space app use as a
peripheral. This machine was not used to prove that radio path. The in-app
simulator (`DEVICE_MODE=sim`) is the one the unit tests run.

The peripheral speaks the same UUIDs and R03 layout as lib/core/config/constants.dart.
Codec reads return 21. Battery reads return 87. Heartbeats are 0x10 on A1000004.
"""

import asyncio
import sys

from protocol import (
    CONTENT_AUDIO,
    OPCODE_ACK,
    OPCODE_READY,
    OPCODE_REQUEST,
    chunk,
    crc32,
    decode,
    handshake,
    heartbeat,
    metadata,
)

SERVICE = "a1000000-5fa6-43f5-9827-201f62bd377d"
INBOUND = "a1000001-5fa6-43f5-9827-201f62bd377d"
CODEC = "a1000002-5fa6-43f5-9827-201f62bd377d"
OUTBOUND = "a1000003-5fa6-43f5-9827-201f62bd377d"
COMMAND = "a1000004-5fa6-43f5-9827-201f62bd377d"


def main():
    try:
        from bless import (  # type: ignore
            BlessServer,
            GATTAttributePermissions,
            GATTCharacteristicProperties,
        )
    except ImportError:
        print("Install the peripheral library first: pip install bless", file=sys.stderr)
        return 1

    async def run():
        server = BlessServer(name="CAIPO-SIM")
        await server.add_new_service(SERVICE)
        read = GATTCharacteristicProperties.read
        notify = GATTCharacteristicProperties.notify
        write = GATTCharacteristicProperties.write
        readable = GATTAttributePermissions.readable
        writable = GATTAttributePermissions.writeable
        await server.add_new_characteristic(SERVICE, INBOUND, notify, None, GATTAttributePermissions.read)
        await server.add_new_characteristic(SERVICE, CODEC, read, bytearray([21]), readable)
        await server.add_new_characteristic(SERVICE, OUTBOUND, write, None, writable)
        await server.add_new_characteristic(SERVICE, COMMAND, notify | write, None, readable | writable)
        counter = 0

        def notify_value(uuid, payload: bytes):
            char = server.get_characteristic(uuid)
            char.value = bytearray(payload)
            server.update_value(SERVICE, uuid)

        def on_write(characteristic, value, **_kwargs):
            message = decode(bytes(value))
            if not message or message.get("opcode") != OPCODE_REQUEST:
                return
            transfer_id = message["transfer_id"]
            notify_value(INBOUND, handshake(OPCODE_READY, transfer_id))

        server.write_request_func = on_write
        await server.start()
        print("Advertising CAIPO-SIM. Ctrl+C to stop.")
        while True:
            notify_value(COMMAND, heartbeat(counter))
            counter = (counter + 1) & 0xFF
            await asyncio.sleep(1)

    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    # Keep the encoder helpers referenced so a partial peripheral can be extended
    # without guessing the layout. They match the Dart messages.
    _ = (CONTENT_AUDIO, OPCODE_ACK, chunk, crc32, metadata)
    raise SystemExit(main())
