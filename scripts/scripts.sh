# Install the dependencies
cd flutter_integration_test && flutter pub get && cd .. && cd packages/net-kit && flutter pub get && cd .. && cd ..
# Run chrome app in Github Codespaces

cd flutter_integration_test && flutter run -d web-server