import os
from dotenv import load_dotenv

load_dotenv()

TELEGRAM_BOT_TOKEN: str = os.environ["TELEGRAM_BOT_TOKEN"]
WEBHOOK_URL: str = os.environ["WEBHOOK_URL"]          # e.g. https://xxx.run.app
WEBHOOK_SECRET: str = os.environ.get("WEBHOOK_SECRET", "")

R2_ACCOUNT_ID: str = os.environ["R2_ACCOUNT_ID"]
R2_ACCESS_KEY_ID: str = os.environ["R2_ACCESS_KEY_ID"]
R2_SECRET_ACCESS_KEY: str = os.environ["R2_SECRET_ACCESS_KEY"]
R2_BUCKET_NAME: str = os.environ["R2_BUCKET_NAME"]

# Comma-separated Telegram user IDs allowed to use the bot
_raw_ids = os.environ.get("ALLOWED_USER_IDS", "")
ALLOWED_USER_IDS: set[int] = {int(i.strip()) for i in _raw_ids.split(",") if i.strip()}

# ── content catalogue ─────────────────────────────────────────────────────────
RIWAYAT: dict[str, str] = {
    "hafs":            "حفص عن عاصم",
    "warsh":           "ورش عن نافع",
    "qalun":           "قالون عن نافع",
    "al_duri_abi_amr": "الدوري عن أبي عمرو",
}

MUTOON: dict[str, str] = {
    "shatibiyyah":    "الشاطبية",
    "jazariyyah":     "الجزرية",
    "tuhfat_al_atfal":"تحفة الأطفال",
}
