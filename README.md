# Scraps to Snacks Mobile

Scraps to Snacks is a Flutter application that helps users turn available ingredients into practical recipe ideas. Supabase provides authentication and backend services, while server-side AI functions analyze pantry input and generate structured cooking guidance.

## Implemented features

- Ingredient and pantry input
- Pantry-image scanning through a server-side AI function
- Recipe generation based on available ingredients
- Follow-up recipe questions and contextual cooking assistance
- Image selection from the device
- Supabase-backed authentication and application data
- Mobile-first Flutter interface

## Technology

- Flutter and Dart
- Provider for application state
- Supabase Flutter client, Postgres, and Edge Functions
- Groq-compatible text and vision models
- Image Picker, Google Fonts, and Intl

## Local development

```bash
flutter pub get
flutter run
```

Configure the public Supabase URL and publishable/anonymous key for the Flutter client. Deploy and configure these Edge Functions as required by the application:

- `scan-pantry`
- `generate-recipe`
- `ask-recipe`

Keep the Groq key, Supabase service-role key, and other privileged credentials in Supabase Edge Function secrets. Never place them in Flutter source code or a committed `.env` file.

## Verification

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Generated recipes should be checked for allergies, dietary restrictions, food safety, and ingredient suitability before use.
