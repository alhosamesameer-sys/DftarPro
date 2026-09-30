# Build verification

The source archive was inspected before upload. Local Dart import references were checked and all referenced local files exist. The available execution environment does not contain the Flutter/Dart SDK, so a local Flutter build could not be run here.

GitHub Actions is configured to run:
- flutter pub get
- flutter analyze
- flutter test
- flutter build apk --debug

The workflow uploads the resulting debug APK as a workflow artifact.

Latest requested UI fixes: startup splash artwork, base-currency account totals, and enlarged/repositioned PDF logo/title header.
Android build verification 2.

Automatic backup scheduling verification 2.
