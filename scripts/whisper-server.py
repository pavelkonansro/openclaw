#!/usr/bin/env python3
"""Локальный Whisper API сервер, совместимый с OpenAI /v1/audio/transcriptions."""

import sys
import os
import tempfile
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

_model = None


def get_model():
    global _model
    if _model is None:
        from faster_whisper import WhisperModel
        print("Загрузка модели whisper base...")
        _model = WhisperModel("medium", device="cpu", compute_type="int8")
        print("Модель загружена!")
    return _model


def parse_multipart(rfile, content_type):
    """Простой парсер multipart/form-data без cgi модуля."""
    boundary = content_type.split("boundary=")[1].strip()
    if boundary.startswith('"') and boundary.endswith('"'):
        boundary = boundary[1:-1]
    boundary = boundary.encode()

    raw = rfile.read()
    parts = raw.split(b"--" + boundary)
    result = {}

    for part in parts:
        if b"Content-Disposition" not in part:
            continue
        header_end = part.find(b"\r\n\r\n")
        if header_end == -1:
            continue
        header = part[:header_end].decode(errors="replace")
        body = part[header_end + 4:]
        if body.endswith(b"\r\n"):
            body = body[:-2]

        # Извлекаем name
        for item in header.split(";"):
            item = item.strip()
            if item.startswith("name="):
                name = item.split("=", 1)[1].strip('"')
                result[name] = body
                break

    return result


class WhisperHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/v1/audio/transcriptions":
            self.send_error(404)
            return

        content_type = self.headers.get("Content-Type", "")
        if "multipart/form-data" not in content_type:
            self.send_error(400, "Expected multipart/form-data")
            return

        content_length = int(self.headers.get("Content-Length", 0))
        raw_body = self.rfile.read(content_length)
        body_reader = type("R", (), {"read": lambda s: raw_body})()

        try:
            parts = parse_multipart(body_reader, content_type)
        except Exception as e:
            self.send_error(400, f"Parse error: {e}")
            return

        if b"file" not in parts and "file" not in parts:
            self.send_error(400, "Missing 'file' field")
            return

        file_data = parts.get("file", parts.get(b"file", b""))
        language = parts.get("language", parts.get(b"language", b"ru"))
        if isinstance(language, bytes):
            language = language.decode()

        with tempfile.NamedTemporaryFile(suffix=".ogg", delete=False) as tmp:
            tmp.write(file_data)
            tmp_path = tmp.name

        try:
            model = get_model()
            segments, info = model.transcribe(tmp_path, language=language)
            text = " ".join(seg.text.strip() for seg in segments)

            response = json.dumps({"text": text})
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(response.encode())
            print(f"Транскрибировано ({info.language}): {text[:100]}...")
        except Exception as e:
            self.send_error(500, str(e))
        finally:
            os.unlink(tmp_path)

    def log_message(self, format, *args):
        print(f"[whisper] {args[0]}")


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9876
    server = HTTPServer(("0.0.0.0", port), WhisperHandler)
    print(f"Whisper API: http://0.0.0.0:{port}/v1/audio/transcriptions")
    server.serve_forever()


if __name__ == "__main__":
    main()
