"""Local stand-in for FloBrain. Not the live API and not its schema.

Field names match the placeholders the Flutter client already sends
(`access`, `refresh`, `email`, `password`). Run:

    python tools/flobrain_mock/server.py

Then point a client at http://127.0.0.1:8765. The app's BACKEND_MODE=mock
does not use this process; it answers inside the app. This server is for
trying the same canned routes over HTTP on the laptop.
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json

HOST = "127.0.0.1"
PORT = 8765

ACCOUNTS = {}
CHATS = {}
NEXT_ID = 1
CANNED_TRANSCRIPT = "This is a simulated transcript."
CANNED_REPLY = "Simulated FloBrain reply."


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._route("GET")

    def do_POST(self):
        self._route("POST")

    def do_PATCH(self):
        self._route("PATCH")

    def do_DELETE(self):
        self._route("DELETE")

    def log_message(self, fmt, *args):
        print("%s %s" % (self.command, self.path))

    def _route(self, method):
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b""
        body = json.loads(raw.decode("utf-8") or "{}") if raw else {}
        path = self.path.split("?", 1)[0]
        auth = self.headers.get("Authorization", "")
        token = auth[7:] if auth.startswith("Bearer ") else ""

        if method == "POST" and path in ("/api/auth/signin/", "/api/auth/register/"):
            email = str(body.get("email", ""))
            password = str(body.get("password", ""))
            if not email or not password:
                return self._send(400, {"error": "Email and password are required.", "details": ""})
            account = ACCOUNTS.setdefault(email, {"email": email, "generation": 0})
            account["password"] = password
            return self._send(200, _tokens(account))

        if method == "POST" and path == "/api/auth/refresh/":
            refresh = str(body.get("refresh", ""))
            account = next((item for item in ACCOUNTS.values() if item.get("refresh") == refresh), None)
            if account is None:
                return self._send(401, {"error": "Refresh token was not recognised.", "details": ""})
            return self._send(200, _tokens(account))

        if method == "POST" and path == "/api/auth/signout/":
            return self._send(200, {"ok": True})

        if method == "POST" and path == "/api/speech/stt/":
            return self._send(200, {"text": CANNED_TRANSCRIPT})

        if method == "POST" and path == "/api/speech/tts/":
            return self._send(200, {"audio": [], "text": str(body.get("text", ""))})

        account = next((item for item in ACCOUNTS.values() if item.get("access") == token), None)
        if account is None:
            return self._send(401, {"error": "Sign in required.", "details": ""})

        if method == "GET" and path == "/api/profile/":
            return self._send(200, {"email": account["email"]})

        if method == "POST" and path.endswith("/send/") and "/api/brain/chats/" in path:
            chat_id = [part for part in path.split("/") if part][-2]
            text = str(body.get("text") or body.get("message") or "")
            history = CHATS.setdefault(chat_id, [])
            history.append({"role": "user", "text": text})
            reply = "%s You said: %s" % (CANNED_REPLY, text)
            history.append({"role": "assistant", "text": reply})
            return self._send(200, {"id": chat_id, "reply": reply, "messages": history})

        if method == "POST" and path == "/api/brain/chats/":
            global NEXT_ID
            chat_id = str(NEXT_ID)
            NEXT_ID += 1
            CHATS[chat_id] = []
            return self._send(201, {"id": chat_id})

        if method == "GET" and path == "/api/brain/chats/":
            return self._send(200, {"results": [{"id": chat_id} for chat_id in CHATS]})

        return self._send(200, {"ok": True})

    def _send(self, status, payload):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def _tokens(account):
    account["generation"] = account.get("generation", 0) + 1
    account["access"] = "mock-access-%s-%s" % (account["email"], account["generation"])
    account["refresh"] = "mock-refresh-%s" % account["email"]
    return {"access": account["access"], "refresh": account["refresh"]}


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print("Mock FloBrain on http://%s:%s" % (HOST, PORT))
    server.serve_forever()
