# CAIPO-SIM laptop peripheral

Advertises the name `CAIPO-SIM` and the service `a1000000-5fa6-43f5-9827-201f62bd377d`. Codec reads as 21. A heartbeat (`0x10` plus a counter) goes out on `A1000004` every second. Writes on `A1000003` are decoded with `protocol.py`.

This is for a real phone's Bluetooth stack before the ESP32 firmware exists. The in-app simulator does not need it.

## Windows and macOS

```bash
pip install bless
python tools/caipo_sim/sim.py
```

The computer needs a Bluetooth radio that allows a peripheral app. `bless` is the only extra package. If import fails, the script says so and exits.

`protocol.py` has no dependencies. It is the byte layout the peripheral and the app share.
