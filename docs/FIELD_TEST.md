# Field test

Run this on a real CAIPO and a real phone later. This build has not been through it. `DEVICE_MODE=sim` does not count.

Each row is the situation, what should happen, and how to check.

## 30 minutes outside, screen locked

Expected: BLE stays up or comes back. Voice turns still complete when the phone has mobile data. The Android connected-device notification should remain. iOS should restore the central.

Check: lock the phone, wait 30 minutes, unlock. Dashboard should show Connected, or Reconnecting and then Connected. Diagnostics should show the link log rather than a single drop with no retry.

## The OS kills the app

Expected: the next launch reconnects if auto-connect is on. A recording that failed to send is still in Conversation as "Not sent".

Check: swipe the app away, open it, confirm the device returns and the unsent row is still there. Tap Retry after the link and the network are back.

## Bluetooth toggled off and on

Expected: the app reports the drop, then reconnects when the radio returns. A "Connection lost" notification is posted if that preference is on.

Check: turn Bluetooth off, read the dashboard, turn it on, and wait for Connected.

## Phone has no internet

Expected: the voice recording is kept. Conversation shows "Not sent" and Retry. The app does not drop the audio and does not claim FloBrain replied.

Check: enable airplane mode with Bluetooth still on, finish a turn, and confirm the row and that Retry is present. Restore the network and retry.

## Hotspot off, then on

Expected: with the proposed command flag off, the app does not pretend to know Wi-Fi state. Settings still shows the hotspot note: turn the hotspot on outside when the camera is needed. The app cannot switch the hotspot on itself.

With `PROPOSED_COMMANDS` on and STATUS bit 4 clear, Capture, Record video, and Live view show "Needs WiFi", and the dashboard shows the hotspot hint plus the pending-upload count.

Check: read those labels before and after the hotspot is on. With `PROPOSED_STREAM` off, Live view stays off and does not play a sample as the camera. With that flag on, Live view shows "Starting camera..." and a 2-minute countdown, then an MJPEG picture from the device on the local network. Viewing the camera from another network is still an open question in `docs/WIFI_CONTRACT_QUESTIONS.md`.

## Battery under 20%

Expected: the state light goes red and a low-battery notification is posted if that preference is on. Charging is red until a STATUS frame says the charging bit is set, and that frame is ignored while `PROPOSED_COMMANDS` is off.

Check: drain or simulate the battery characteristic below 20% and confirm the light and the notification list.
