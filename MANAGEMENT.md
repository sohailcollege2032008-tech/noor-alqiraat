# Noor Al-Qira'at — Management Guide

## R2 Bucket Folder Structure

```
bucket-root/
├── hafs/              # Quran — Hafs 'an 'Asim
│   ├── 001.mp3        # Al-Fatihah
│   ├── 002.mp3        # Al-Baqarah
│   └── ...  114.mp3
├── warsh/             # Quran — Warsh 'an Nafi'
│   └── 001.mp3 … 114.mp3
├── qalun/
│   └── 001.mp3 … 114.mp3
├── al_duri_abi_amr/
│   └── 001.mp3 … 114.mp3
├── shatibiyyah/       # Matn — Al-Shatibiyyah (25 chapters)
│   └── 001.mp3 … 025.mp3
├── jazariyyah/        # Matn — Al-Jazariyyah (9 chapters)
│   └── 001.mp3 … 009.mp3
└── tuhfat_al_atfal/   # Matn — Tuhfat Al-Atfal (3 chapters)
    └── 001.mp3 … 003.mp3
```

All filenames are **zero-padded 3 digits** (`001.mp3`, not `1.mp3`).

---

## Telegram Admin Bot

### Commands
| Command   | Description                          |
|-----------|--------------------------------------|
| `/start`  | Begin a new upload session           |
| `/cancel` | Cancel the current upload at any step|

### Upload Flow
```
/start
  → Category: [Quran] or [Mutoon]
  → Quran  → select Riwayah → enter Surah number (1-114) → send .mp3
  → Mutoon → select Matn   → enter Chapter number        → send .mp3
```
The bot renames the file to `NNN.mp3` and uploads it to the correct R2 path.

### Adding Authorized Users
1. Get the user's Telegram ID (they can send `/start` to @userinfobot).
2. Open the Cloud Run service in Google Cloud Console.
3. Go to **Edit & Deploy New Revision** → **Variables & Secrets**.
4. Update `ALLOWED_USER_IDS` — comma-separated, e.g. `2035706891,1234567890`.
5. Deploy. No code change needed.

### Adding a New Riwayah or Matn
1. Add its folder to `config.py` (`RIWAYAT` or `MUTOON` dict).
2. Add its entry to `assets/data/quran_index.json` or `assets/data/mutoon_index.json`.
3. Redeploy the bot (`gcloud run deploy …`).
4. Rebuild and publish the Flutter app.

---

## Cloud Run Deployment

### Prerequisites
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud services enable run.googleapis.com artifactregistry.googleapis.com
```

### 1. Create Artifact Registry repository (once)
```bash
gcloud artifacts repositories create noor-alqiraat \
  --repository-format=docker \
  --location=us-central1
```

### 2. Build & push the Docker image
```bash
cd admin_bot

gcloud builds submit \
  --tag us-central1-docker.pkg.dev/YOUR_PROJECT_ID/noor-alqiraat/admin-bot:latest
```

### 3. Deploy to Cloud Run
```bash
gcloud run deploy noor-alqiraat-bot \
  --image us-central1-docker.pkg.dev/YOUR_PROJECT_ID/noor-alqiraat/admin-bot:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "TELEGRAM_BOT_TOKEN=YOUR_TOKEN,\
WEBHOOK_SECRET=YOUR_SECRET,\
R2_ACCOUNT_ID=YOUR_ACCOUNT_ID,\
R2_ACCESS_KEY_ID=YOUR_KEY,\
R2_SECRET_ACCESS_KEY=YOUR_SECRET_KEY,\
R2_BUCKET_NAME=YOUR_BUCKET,\
ALLOWED_USER_IDS=2035706891"
```

### 4. Set the Webhook URL (after first deploy)
Cloud Run gives you a URL like `https://noor-alqiraat-bot-xxx-uc.a.run.app`.

```bash
# Set WEBHOOK_URL env var to that URL, then redeploy:
gcloud run services update noor-alqiraat-bot \
  --update-env-vars WEBHOOK_URL=https://noor-alqiraat-bot-xxx-uc.a.run.app \
  --region us-central1
```

The bot registers the webhook with Telegram automatically on startup.

---

## GitHub Setup

```bash
cd D:/Projects/noor_alqiraat

git init
git remote add origin https://github.com/YOUR_USERNAME/noor-alqiraat.git

git add .
git commit -m "Initial commit: Flutter app + Telegram admin bot"
git branch -M main
git push -u origin main
```

**Verify `.env` is not tracked:**
```bash
git status   # .env must NOT appear in the list
```

---

## Manual Uploader (fallback)

```bash
cd admin_tools
pip install boto3 python-dotenv
python r2_uploader.py
```

Supports single-file and batch folder upload — see the script's menu.
