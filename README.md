# Nostalgia Time Machine

## Firebase Functions Secrets

This project uses Firebase Functions secrets for third-party APIs.

### Required for AI chat + quiz + year news

- `OPENAI_API_KEY`
- `NYT_API_KEY`

Set secrets:

```bash
firebase functions:secrets:set OPENAI_API_KEY
firebase functions:secrets:set NYT_API_KEY
```

Deploy functions:

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```
