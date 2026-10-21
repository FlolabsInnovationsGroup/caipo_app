# What the CAIPO mobile app needs from the multimodal team

From: CAIPO mobile app (`FlolabsInnovationsGroup/caipo_app`)
To: Multimodal team (`multi-modal-perception`)
Date: 22 Oct 2026

The app never calls this service directly. It calls FloBrain, and FloBrain calls `POST {MULTIMODAL_SERVICE_URL}/process` through `brain/llm/multimodal_adapter.py`. These are the capabilities CAIPO needs underneath.

## 1. Image input (blocking the V1)

John's V1: CAIPO or the phone takes a picture, the user asks "what is this building" or "what are the ingredients", and the answer comes back. That is the minimum: anything ChatGPT on a phone can do with a photo.

Today `/process` and `/openAI` accept `text_input` and `audio_file` only. There is no image input.

Needed:

- An image input on `/process`, for example a multipart `image_file` field (JPEG or PNG, up to 4 MB, about 1024 px wide from the app).
- A vision-capable model behind it. The `minicpm_test_case` folder is an experiment; an existing hosted model is fine. John said no training.
- Agree the field name and format with the FloBrain backend team, since they make the call.

Done when: text plus image returns an answer about the image.

## 2. Text-to-speech (needed for answers on CAIPO's speaker)

There is no TTS in the service. CAIPO has no screen, so the answer must be spoken.

Needed: text in, audio out. Simplest is raw 16-bit PCM, 16 kHz, mono. WAV at another rate is fine if agreed with the backend team. The app encodes it to Opus for the device. A voice that is clear on a small speaker matters: the IoT team reported the current speaker's sound quality is poor.

## 3. Speech-to-text (exists, confirm)

`/process` already transcribes `audio_file` with `gpt-4o-mini-transcribe`. Please confirm:

- WAV 16 kHz mono 16-bit PCM is accepted. That is what the app produces from CAIPO's recording.
- Whether it can return the transcript on its own, not only a reply. The app shows "Heard: ..." to the user.

## 4. Latency

The full chain is CAIPO → phone → FloBrain → this service → back. The app waits 20 s per request today. Please share typical and worst-case times for:

- text only
- text + image
- audio in (transcribe + reply)
- TTS for a reply of about 2 sentences

John also asked for a latency comparison between the phone path and the Pi going straight to FloBrain. These numbers are the input for that decision.

## 5. Contract stability

When the request or response of `/process` changes, please tell the FloBrain backend team first. The app depends on FloBrain's chat response staying the same, not on this service directly.
