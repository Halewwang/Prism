"""Local HTTP pages for LinkPreviewUITests; run before the UI suite."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from html import escape
import re


class PreviewFixture(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/redirect", "/ua-redirect"):
            self.send_response(302)
            self.send_header("Location", "/ua" if self.path == "/ua-redirect" else "/next")
            self.end_headers()
            return
        if self.path == "/ua":
            user_agent = self.headers.get("User-Agent", "")
            version = re.search(r"\bVersion/(\d+(?:\.\d+)*)\b", user_agent) if "Safari/" in user_agent else None
            body = f'''<main><h1>Browser identity</h1>
              <p id="http-ua">HTTP User-Agent: {escape(user_agent)}</p>
              <p>Safari Version: {version.group(1) if version else 'unavailable'}</p>
              <p id="navigator-ua"></p><p><a href="/start">Return to start</a></p></main>
              <script>document.getElementById('navigator-ua').textContent = 'Navigator User-Agent: ' + navigator.userAgent;</script>'''
        elif self.path == "/next":
            body = '<h1>Next fixture page</h1><p>Native WebKit navigation works.</p><a href="/start">Return to start</a>'
        else:
            body = '''<header><b>Developer</b><span>Documentation</span></header>
              <main><small>DESIGN &amp; DEVELOPMENT</small><h1>好的界面，<br>让想法自然发生。</h1>
              <p>在浮窗中浏览网页，再用喜欢的浏览器继续。</p>
              <p><a href="/next">Go to next</a> &nbsp; <a href="/next" target="_blank">Open new window</a></p>
              <label for="preview-input">Preview input</label><input id="preview-input" autocomplete="off">
              <p><a href="/ua-redirect">Check browser identity</a></p>
              </main>'''
        html = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Prism preview fixture</title><style>
          *{box-sizing:border-box}body{margin:0;color:#1d1d1f;font-family:system-ui;background:white}
          header{display:flex;justify-content:space-between;padding:22px 26px;border-bottom:1px solid #eee}
          header b{font-size:23px}header span{color:#666;font-size:13px}main{padding:72px 32px}
          small{letter-spacing:.2em;color:#666}h1{font-size:38px;letter-spacing:-1px}p{line-height:1.8;color:#666;font-size:14px}
          a{color:#645bdf}label{display:block;margin-top:30px;font-size:12px;color:#666}
          input{margin-top:8px;padding:9px;border:1px solid #ddd;border-radius:6px;max-width:100%}
          </style><body>''' + body + '</body></html>'
        data = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 18771), PreviewFixture).serve_forever()
