# YouTube API Setup Guide

## Quick Start

To enable YouTube search in your app, you need to add your YouTube Data API v3 key.

### Steps:

1. **Get a YouTube API Key:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one
   - Enable the **YouTube Data API v3**
   - Go to **Credentials** and create an API key
   - Copy your API key

2. **Add Your API Key:**
   - Open `lib/config/youtube_config.dart`
   - Replace `'YOUR_YOUTUBE_API_KEY_HERE'` with your actual API key

3. **Test the Integration:**
   - Open the Add Song screen
   - Search for a song (e.g., "Smells Like Teen Spirit")
   - You should see real YouTube results with thumbnails
   - Tap a result to add it to your playlist

## API Key Security

**Important:** The API key is currently stored in the code for simplicity. For production apps, consider:
- Using environment variables
- Using Flutter's `--dart-define` flag
- Using a backend service to proxy API requests

## Quota Limits

The YouTube Data API has daily quota limits:
- Free tier: 10,000 units per day
- Each search request costs 100 units
- This allows approximately 100 searches per day

For higher limits, you may need to request a quota increase from Google.

## Troubleshooting

If you see an error message:
- **"YouTube API key not configured"**: Add your API key in `lib/config/youtube_config.dart`
- **"Failed to search YouTube"**: Check your internet connection and API key validity
- **No results**: Try a different search term or check if the API key has proper permissions
