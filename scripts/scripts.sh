# Install the dependencies
cd flutter_integration_test && flutter pub get && cd .. && cd packages/net-kit && flutter pub get && cd .. && cd ..
# Run chrome app in Github Codespaces
cd flutter_integration_test && flutter run -d web-server

# Integration test the package
cd flutter_integration_test && flutter test integration_test

# Test the package
cd packages/net-kit && dart format --set-exit-if-changed . && dart analyze --fatal-infos --fatal-warnings && dart test && cd .. && cd ..

# Publish the package
cd packages/net-kit && dart format --set-exit-if-changed . && dart analyze --fatal-infos --fatal-warnings && dart test &&  dart pub publish  && cd .. && cd ..