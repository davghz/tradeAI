# TradeAI

TradeAI is a Theos-based iOS app (targeting iOS 13.2.3) for trading dashboards, portfolio views, and AI-assisted signals.

## Build (Theos)

Prereqs:
- Theos installed (e.g. `/home/davgz/theos`)
- iOS 13.2.3 SDK available at `$THEOS/sdks/iPhoneOS13.2.3.sdk`

From this repo:

```bash
export THEOS=/home/davgz/theos
# Optional: ensure the SDK target is set (already in Makefile)
# TARGET := iphone:clang:13.2.3:13.2

make package
```

This produces a `.deb` in `packages/`.

### Install on device (SSH)

```bash
export THEOS=/home/davgz/theos
export THEOS_DEVICE_IP=10.0.0.9
export THEOS_DEVICE_PORT=22
export THEOS_DEVICE_PASSWORD=alpine

make package install
```

## API Keys / Secrets

No real API keys are included in this repo. Use your own credentials via the Settings screen or by providing JSON files:

- `iostest2.json` (ECDSA)
- `linux2.json` (Ed25519)

Both are **placeholders** here. Replace with your own values before building or running.
