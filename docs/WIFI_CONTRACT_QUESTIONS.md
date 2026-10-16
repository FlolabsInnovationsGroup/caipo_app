# Wi-Fi contract questions

The local live stream is proposed and specified. These questions are only the parts that proposal does not cover. Nothing here is a change to the confirmed BLE contract.

The proposal already decides: same Wi-Fi or the phone hotspot, MJPEG over HTTP, 640×480 at 15 fps, discovery by `STREAM_READY` (IPv4, port, 16-byte token), and a 2-minute stop. Those are not open questions.

## Still open

1. Remote viewing from anywhere later. The proposal is local only. Is a later path through FloBrain, and if so what URL and auth does the phone use when it is not on the camera's network?
2. Who creates `device_token` in the proposed Wi-Fi provisioning JSON, and is that token the same 16 bytes as the stream token?
3. Photos and videos uploaded by the Pi. `GET /api/media/` and `GET /api/media/{id}/` are not in the published OpenAPI document. What is the upload path, the file types, and the JSON the app should expect?

`PROPOSED_STREAM`, `PROPOSED_WIFI`, and `PROPOSED_MEDIA` stay off until those answers exist. Nothing from the camera is sent over BLE.
