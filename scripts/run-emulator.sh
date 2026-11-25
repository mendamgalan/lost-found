#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:-emulator-5554}"
command -v flutter >/dev/null || { echo 'Flutter SDK-аа PATH-д нэмнэ үү.'; exit 1; }
node -e 'if(Number(process.versions.node.split(".")[0])<22){console.error("Node 22+ шаардлагатай.");process.exit(1)}'
[[ -d functions/node_modules ]] || npm --prefix functions ci
[[ -d tools/firestore-tests/node_modules ]] || npm --prefix tools/firestore-tests ci
flutter pub get
mkdir -p .emulator-data
import_args=()
[[ -f .emulator-data/firebase-export-metadata.json ]] && import_args=(--import .emulator-data)
node scripts/emulator-cli.cjs emulators:start --only auth,firestore,storage,functions --project demo-lost-found --export-on-exit .emulator-data "${import_args[@]}" > .emulator-data/session.log 2>&1 &
emulator_pid=$!
cleanup(){ kill -INT "$emulator_pid" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
ready=false
for attempt in {1..60}; do
 if node -e 'const net=require("node:net");Promise.all([9099,8080,9199,5001].map(port=>new Promise((resolve,reject)=>{const s=net.createConnection({host:"127.0.0.1",port});s.setTimeout(500);s.on("connect",()=>{s.destroy();resolve()});s.on("error",reject);s.on("timeout",()=>{s.destroy();reject()})}))).then(()=>process.exit(0),()=>process.exit(1))' >/dev/null 2>&1; then ready=true; break; fi
 kill -0 "$emulator_pid" 2>/dev/null || { cat .emulator-data/session.log; exit 1; }
 sleep 1
done
[[ "$ready" == true ]] || { echo 'Firebase эхлээгүй. .emulator-data/session.log-ийг шалгана уу.'; exit 1; }
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node scripts/seed-demo.cjs
flutter run -d "$device" --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.2.2
