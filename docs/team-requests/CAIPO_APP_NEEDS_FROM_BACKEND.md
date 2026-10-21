# What the CAIPO mobile app needs from the FloBrain backend team

From: CAIPO mobile app (`FlolabsInnovationsGroup/caipo_app`)
To: FloBrain backend team
Date: 22 Oct 2026

The app now uses FloBrain's real auth and chat contract, which was read from the backend code on `main` (merge `7dbedb23`). Below is what it still needs, in priority order.

## 1. Send the chat image to the model (blocking the V1)

John's V1 is a photo plus a question, answered by FloBrain. The app sends that today:

```
POST /api/brain/chats/{id}/send/
Authorization: Bearer <access>
{ "text": "What is this building?", "image": "data:image/jpeg;base64,..." }
```

FloBrain stores `image` but never sends it to the model:

- `brain/views.py`, `_build_llm_messages`: user messages are added only `if msg.text`, with text content. The image is dropped.
- `brain/llm/multimodal_adapter.py`: posts only `text_input` to `{MULTIMODAL_SERVICE_URL}/process`.

Needed:

1. Pass the image of the current message to the adapter, and from there to the multimodal service, which needs its own change (see the multimodal file).
2. Tell the app the accepted format: data URL (what the app sends), raw base64, or an uploaded URL.
3. A size limit. The app caps photos at 4 MB and about 1024 px wide.

Done when: the same request returns an answer that is about the photo. The app then turns the feature on with `FLOBRAIN_VISION=true`. It is blocked on live builds until then.

## 2. Speech-to-text route

The voice loop (CAIPO records, FloBrain answers, CAIPO speaks) cannot run live. FloBrain has no speech route. The multimodal service can already transcribe (`gpt-4o-mini-transcribe`), so this is mostly exposing it.

The app has a client ready, off by default, using this proposed shape. You can change it, but please tell us:

```
POST /api/speech/transcribe/
Authorization: Bearer <access>
Body: WAV, 16 kHz mono 16-bit PCM
-> 200 { "text": "..." }
```

## 3. Text-to-speech route

Needed so answers play on CAIPO's speaker. Proposed:

```
POST /api/speech/synthesize/
{ "text": "...", "voice": "default" }
-> 200 audio bytes. Simplest for the app: raw 16-bit PCM, 16 kHz, mono.
   WAV at another rate also works, but tell us, because the app then parses and resamples it.
```

## 4. HTTPS and a test account

- `api.flobrain.ai` refused port 443 when tested on 15 Oct. The app only makes authenticated calls over HTTPS. Please confirm 443 works.
- A test account for live testing, sent privately and never in a repo or chat.

## 5. Timeouts

The app waits 20 s per request. The adapter waits up to 60 s for the multimodal service. A photo question can be slower than 20 s. Please share typical and worst-case response times for chat send with an image, and the app will set its timeout to match.

## 6. Please don't change these without telling the app team

| Call | Request | Response the app parses |
| --- | --- | --- |
| Every authenticated call | `Authorization: Bearer <access>` | |
| `POST /api/auth/signin/`, `/register/` | `email`, `password` | `access_token`, `refresh_token` |
| `POST /api/auth/refresh/` | `refresh` | `access` |
| `POST /api/auth/signout/` | `refresh_token` + Bearer | |
| `POST /api/brain/chats/` | `title` | `id` |
| `POST /api/brain/chats/{id}/send/` | `text`, `image` | `messages`. The reply is the last item with `role: "assistant"` |
| Errors | | `{ "error", "details" }` |

The OpenAPI schema lists `tokenAuth`, which is DRF's default. The views read Bearer. Fixing the schema would stop the next client from making the same mistake.

## 7. Later, not blocking

- `GET /api/media/` for photos and videos the Pi uploads (shape in `docs/WIFI_CONTRACT_QUESTIONS.md`).
- Voice and language fields in `/api/settings/preferences/`. Today the app keeps them on the phone.
