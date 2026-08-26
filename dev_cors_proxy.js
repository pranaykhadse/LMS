// Local dev-only CORS proxy for staging.trainingpipeline.com.
//
// Flutter web (CanvasKit) makes real browser requests, and the staging API
// doesn't send Access-Control-Allow-Origin headers, so browsers block it
// unless Chrome is launched with --disable-web-security (which also blocks
// installing extensions). This proxy sits between the app and the API,
// adding the missing CORS headers, so the app can run in any normal Chrome
// window/profile without special flags.
//
// Usage:
//   node dev_cors_proxy.js
//   flutter run -d chrome --dart-define=SERVER_URL=http://localhost:8081/api/web/

const http = require('http');
const https = require('https');
const { URL } = require('url');

const TARGET_HOST = 'staging.trainingpipeline.com';
const PROXY_PORT = 8081;

function forward(req, res, hostname, path) {
  const proxyReq = https.request(
    {
      hostname,
      port: 443,
      path,
      method: req.method,
      headers: { ...req.headers, host: hostname },
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode, {
        ...proxyRes.headers,
        'Access-Control-Allow-Origin': '*',
      });
      proxyRes.pipe(res);
    },
  );

  proxyReq.on('error', (err) => {
    res.writeHead(502);
    res.end(`Proxy error: ${err.message}`);
  });

  req.pipe(proxyReq);
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Generic image/asset passthrough: /img?url=<encoded full URL> - lets
  // debug-web builds load images from ANY host (e.g.
  // test.login.trainingpipeline.com logos), not just TARGET_HOST. Only
  // GET is supported here, matching how images are actually fetched.
  if (req.url.startsWith('/img?')) {
    const rawUrl = req.url.slice('/img?'.length).replace(/^url=/, '');
    const target = new URL(decodeURIComponent(rawUrl));
    forward(req, res, target.hostname, target.pathname + target.search);
    return;
  }

  forward(req, res, TARGET_HOST, req.url);
});

server.listen(PROXY_PORT, () => {
  console.log(`CORS proxy running at http://localhost:${PROXY_PORT} -> https://${TARGET_HOST}`);
});
