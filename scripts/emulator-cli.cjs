// Local HTTP stays on loopback; external downloads retain the configured proxy.
const undici = require("../tools/firestore-tests/node_modules/undici");
if (undici.EnvHttpProxyAgent) {
  undici.ProxyAgent = class extends undici.EnvHttpProxyAgent {
    constructor(options) {
      super({
        httpProxy: options.uri,
        httpsProxy: options.uri,
        noProxy: "localhost,127.0.0.1,::1",
      });
    }
  };
}
require("../tools/firestore-tests/node_modules/firebase-tools/lib/bin/firebase");
