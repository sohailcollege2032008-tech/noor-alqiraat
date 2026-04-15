"""
Noor Al-Qira'at — Telegram Admin Bot
======================================
Runs as a Cloud Run webhook server (no polling).

Conversation flow
-----------------
/start
  → choose category: Quran | Mutoon
  → if Quran:  choose Riwayah  → enter Surah number  → send .mp3
  → if Mutoon: choose Matn     → enter Chapter number → send .mp3
"""

import logging
import io
from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup,
)
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ConversationHandler, ContextTypes, filters,
)

import config
from r2_client import R2Client

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# ── conversation states ────────────────────────────────────────────────────────
(
    CHOOSE_CATEGORY,
    CHOOSE_RIWAYAH,
    CHOOSE_MATN,
    ENTER_NUMBER,
    WAIT_FOR_FILE,
) = range(5)

r2 = R2Client()


# ── auth guard ────────────────────────────────────────────────────────────────
def _authorized(update: Update) -> bool:
    uid = update.effective_user.id
    if uid not in config.ALLOWED_USER_IDS:
        log.warning("Unauthorized access attempt by user %s", uid)
        return False
    return True


# ── /start ────────────────────────────────────────────────────────────────────
async def start(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    if not _authorized(update):
        await update.message.reply_text("⛔ غير مصرح لك باستخدام هذا البوت.")
        return ConversationHandler.END

    keyboard = [
        [InlineKeyboardButton("📖 قرآن كريم", callback_data="cat:quran")],
        [InlineKeyboardButton("📚 متون", callback_data="cat:mutoon")],
    ]
    await update.message.reply_text(
        "مرحباً! اختر نوع المحتوى:",
        reply_markup=InlineKeyboardMarkup(keyboard),
    )
    return CHOOSE_CATEGORY


# ── category chosen ───────────────────────────────────────────────────────────
async def choose_category(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    category = query.data.split(":")[1]
    ctx.user_data["category"] = category

    if category == "quran":
        keyboard = [
            [InlineKeyboardButton(label, callback_data=f"riwayah:{key}")]
            for key, label in config.RIWAYAT.items()
        ]
        await query.edit_message_text(
            "اختر الرواية:", reply_markup=InlineKeyboardMarkup(keyboard)
        )
        return CHOOSE_RIWAYAH
    else:
        keyboard = [
            [InlineKeyboardButton(label, callback_data=f"matn:{key}")]
            for key, label in config.MUTOON.items()
        ]
        await query.edit_message_text(
            "اختر المتن:", reply_markup=InlineKeyboardMarkup(keyboard)
        )
        return CHOOSE_MATN


# ── riwayah chosen ────────────────────────────────────────────────────────────
async def choose_riwayah(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    riwayah = query.data.split(":")[1]
    ctx.user_data["folder"] = riwayah
    label = config.RIWAYAT[riwayah]

    await query.edit_message_text(
        f"✅ الرواية: {label}\n\nأرسل رقم السورة (1-114):"
    )
    return ENTER_NUMBER


# ── matn chosen ───────────────────────────────────────────────────────────────
async def choose_matn(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    matn = query.data.split(":")[1]
    ctx.user_data["folder"] = matn
    label = config.MUTOON[matn]

    await query.edit_message_text(
        f"✅ المتن: {label}\n\nأرسل رقم الباب:"
    )
    return ENTER_NUMBER


# ── number entered ────────────────────────────────────────────────────────────
async def enter_number(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    text = update.message.text.strip()
    try:
        number = int(text)
        if number < 1:
            raise ValueError
    except ValueError:
        await update.message.reply_text("❌ أرسل رقماً صحيحاً (مثال: 1 أو 114)")
        return ENTER_NUMBER

    ctx.user_data["number"] = number
    folder = ctx.user_data["folder"]
    category = ctx.user_data["category"]

    if category == "quran":
        remote_key = R2Client.quran_key(folder, number)
    else:
        remote_key = R2Client.matn_key(folder, number)

    ctx.user_data["remote_key"] = remote_key
    await update.message.reply_text(
        f"📁 المسار على R2: `{remote_key}`\n\nأرسل الآن ملف .mp3",
        parse_mode="Markdown",
    )
    return WAIT_FOR_FILE


# ── file received ─────────────────────────────────────────────────────────────
async def receive_file(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    doc = update.message.document
    if not doc or not doc.file_name.lower().endswith(".mp3"):
        await update.message.reply_text("❌ أرسل ملف .mp3 فقط.")
        return WAIT_FOR_FILE

    remote_key = ctx.user_data["remote_key"]
    await update.message.reply_text(f"⏳ جاري الرفع إلى `{remote_key}` …", parse_mode="Markdown")

    try:
        tg_file = await doc.get_file()
        buf = io.BytesIO()
        await tg_file.download_to_memory(buf)
        buf.seek(0)
        r2.upload_bytes(buf.read(), remote_key)
        await update.message.reply_text(
            f"✅ تم الرفع بنجاح!\n`{remote_key}`\n\nابدأ من جديد بـ /start",
            parse_mode="Markdown",
        )
    except Exception as e:
        log.exception("Upload failed")
        await update.message.reply_text(f"❌ فشل الرفع: {e}")

    ctx.user_data.clear()
    return ConversationHandler.END


# ── cancel ────────────────────────────────────────────────────────────────────
async def cancel(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    ctx.user_data.clear()
    await update.message.reply_text("تم الإلغاء. /start للبدء من جديد.")
    return ConversationHandler.END


# ── app setup ─────────────────────────────────────────────────────────────────
def build_app() -> Application:
    app = Application.builder().token(config.TELEGRAM_BOT_TOKEN).build()

    conv = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            CHOOSE_CATEGORY: [CallbackQueryHandler(choose_category, pattern=r"^cat:")],
            CHOOSE_RIWAYAH:  [CallbackQueryHandler(choose_riwayah, pattern=r"^riwayah:")],
            CHOOSE_MATN:     [CallbackQueryHandler(choose_matn, pattern=r"^matn:")],
            ENTER_NUMBER:    [MessageHandler(filters.TEXT & ~filters.COMMAND, enter_number)],
            WAIT_FOR_FILE:   [MessageHandler(filters.Document.ALL, receive_file)],
        },
        fallbacks=[CommandHandler("cancel", cancel)],
    )
    app.add_handler(conv)
    return app


# ── Cloud Run entry point (webhook) ───────────────────────────────────────────
if __name__ == "__main__":
    import os
    app = build_app()
    port = int(os.environ.get("PORT", 8080))

    app.run_webhook(
        listen="0.0.0.0",
        port=port,
        webhook_url=config.WEBHOOK_URL,
        secret_token=config.WEBHOOK_SECRET,
    )
