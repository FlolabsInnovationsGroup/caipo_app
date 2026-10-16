# Mock FloBrain

Canned auth, chat, speech-to-text, and text-to-speech. This is not the live FloBrain schema. The JSON keys match the placeholders the app sends today (`access`, `refresh`, `email`, `password`).

The Flutter app does not need this process. `BACKEND_MODE=mock` answers inside the app and does not open a socket.

Use this server when you want the same canned routes over HTTP:

```bash
python tools/flobrain_mock/server.py
```

It listens on `http://127.0.0.1:8765`. No extra packages.
