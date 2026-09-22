#!/usr/bin/env bash
set -e
git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter_sdk
export PATH="$PATH:$(pwd)/flutter_sdk/bin"
flutter config --no-analytics
flutter pub get
flutter build web --release --dart-define=API_URL=https://tgback-api.onrender.com
