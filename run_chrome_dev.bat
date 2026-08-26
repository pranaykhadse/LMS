@echo off
cd /d "%~dp0"
start "CORS proxy" cmd /k node dev_cors_proxy.js
flutter run -d chrome --web-port=8000 --dart-define=SERVER_URL=http://localhost:8081/api/web/
