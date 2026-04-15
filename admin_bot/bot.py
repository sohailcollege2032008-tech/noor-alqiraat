"""
Noor Al-Qira'at — Telegram Admin Bot
Cloud Run webhook mode: Flask binds immediately, webhook registered in background thread.
"""

import asyncio
import io
import logging
import os
import threading

from flask import Flask, request
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ConversationHandler, ContextTypes, filters,
)

import config
from r2_client import R2Client

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# ── conversation states ───────────────────────────────────────────────────────
CHOOSE_CATEGORY, CHOOSE_RIWAYAH, CHOOSE_MATN, ENTER_NUMBER, WAIT_FOR_FILE = range(5)

r2 = R2Client()


# ── handlers ─────────────────────────────────────────────────────────────────
def _authorized(update: Update) -> bool:
    uid = update.effective_user.id
    if uid not in config.ALLOWED_USER_IDS:
        log.warning("Unauthorized: %s", uid)
        return False
    return True


async def start(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    if not _authorized(update):
        await update.message.reply_text("⛔ غير مصرح لك باستخدام هذا البوت.")
        return ConversationHandler.END
    keyboard = [
        [InlineKeyboardButton("📖 قرآن كريم", callback_data="cat:quran")],
        [InlineKeyboardButton("📚 متون",       callback_data="cat:mutoon")],
    ]
    await update.message.reply_text("مرحباً! اختر نوع المحتوى:",
                                    reply_markup=InlineKeyboardMarkup(keyboard))
    return CHOOSE_CATEGORY


async def choose_category(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    category = query.data.split(":")[1]
    ctx.user_data["category"] = category
    if category == "quran":
        keyboard = [[InlineKeyboardButton(label, callback_data=f"riwayah:{key}")]
                    for key, label in config.RIWAYAT.items()]
        await query.edit_message_text("اختر الرواية:", reply_markup=InlineKeyboardMarkup(keyboard))
        return CHOOSE_RIWAYAH
    else:
        keyboard = [[InlineKeyboardButton(label, callback_data=f"matn:{key}")]
                    for key, label in config.MUTOON.items()]
        await query.edit_message_text("اختر المتن:", reply_markup=InlineKeyboardMarkup(keyboard))
        return CHOOSE_MATN


async def choose_riwayah(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    riwayah = query.data.split(":")[1]
    ctx.user_data["folder"] = riwayah
    await query.edit_message_text(
        f"✅ الرواية: {config.RIWAYAT[riwayah]}\n\nأرسل رقم السورة (1-114):")
    return ENTER_NUMBER


async def choose_matn(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    matn = query.data.split(":")[1]
    ctx.user_data["folder"] = matn
    await query.edit_message_text(
        f"✅ المتن: {config.MUTOON[matn]}\n\nأرسل رقم الباب:")
    return ENTER_NUMBER


async def enter_number(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        number = int(update.message.text.strip())
        if number < 1:
            raise ValueError
    except ValueError:
        await update.message.reply_text("❌ أرسل رقماً صحيحاً (مثال: 1)")
        return ENTER_NUMBER
    ctx.user_data["number"] = number
    folder   = ctx.user_data["folder"]
    category = ctx.user_data["category"]
    remote_key = (R2Client.quran_key(folder, number) if category == "quran"
                  else R2Client.matn_key(folder, number))
    ctx.user_data["remote_key"] = remote_key
    await update.message.reply_text(
        f"📁 المسار على R2: `{remote_key}`\n\nأرسل الآن ملف .mp3",
        parse_mode="Markdown")
    return WAIT_FOR_FILE


async def receive_file(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    doc = update.message.document
    if not doc or not doc.file_name.lower().endswith(".mp3"):
        await update.message.reply_text("❌ أرسل ملف .mp3 فقط.")
        return WAIT_FOR_FILE
    remote_key = ctx.user_data["remote_key"]
    await update.message.reply_text("⏳ جاري الرفع…")
    try:
        tg_file = await doc.get_file()
        buf = io.BytesIO()
        await tg_file.download_to_memory(buf)
        buf.seek(0)
        r2.upload_bytes(buf.read(), remote_key)
        await update.message.reply_text(
            f"✅ تم الرفع!\n`{remote_key}`\n\nابدأ من جديد بـ /start",
            parse_mode="Markdown")
    except Exception as e:
        log.exception("Upload failed")
        await update.message.reply_text(f"❌ فشل الرفع: {e}")
    ctx.user_data.clear()
    return ConversationHandler.END


async def cancel(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> int:
    ctx.user_data.clear()
    await update.message.reply_text("تم الإلغاء. /start للبدء من جديد.")
    return ConversationHandler.END


# ── Telegram Application (built once, shared across requests) ─────────────────
def _build_app() -> Application:
    app = (Application.builder()
           .token(config.TELEGRAM_BOT_TOKEN)
           .updater(None)
           .build())
    conv = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            CHOOSE_CATEGORY: [CallbackQueryHandler(choose_category, pattern=r"^cat:")],
            CHOOSE_RIWAYAH:  [CallbackQueryHandler(choose_riwayah,  pattern=r"^riwayah:")],
            CHOOSE_MATN:     [CallbackQueryHandler(choose_matn,     pattern=r"^matn:")],
            ENTER_NUMBER:    [MessageHandler(filters.TEXT & ~filters.COMMAND, enter_number)],
            WAIT_FOR_FILE:   [MessageHandler(filters.Document.ALL, receive_file)],
        },
        fallbacks=[CommandHandler("cancel", cancel)],
    )
    app.add_handler(conv)
    return app


# Shared event loop + application
_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
tg_app = _build_app()
_loop.run_until_complete(tg_app.initialize())


def _register_webhook():
    """Called in a background thread after Flask starts."""
    webhook_url = f"{config.WEBHOOK_URL.rstrip('/')}/webhook"
    try:
        future = asyncio.run_coroutine_threadsafe(
            tg_app.bot.set_webhook(url=webhook_url, secret_token=config.WEBHOOK_SECRET),
            _loop,
        )
        future.result(timeout=15)
        log.info("Webhook registered: %s", webhook_url)
    except Exception as e:
        log.error("Webhook registration failed: %s", e)


# ── Flask app ─────────────────────────────────────────────────────────────────
flask_app = Flask(__name__)


@flask_app.get("/")
def health():
    return "Noor Al-Qiraat bot is running", 200


@flask_app.post("/webhook")
def webhook():
    data    = request.get_json(force=True)
    update  = Update.de_json(data, tg_app.bot)
    future  = asyncio.run_coroutine_threadsafe(
        tg_app.process_update(update), _loop
    )
    future.result(timeout=30)
    return "ok", 200


if __name__ == "__main__":
    # Start the shared event loop in a background daemon thread
    loop_thread = threading.Thread(target=_loop.run_forever, daemon=True)
    loop_thread.start()

    # Register webhook 2 s after Flask starts (gives it time to bind)
    threading.Timer(2.0, _register_webhook).start()

    port = int(os.environ.get("PORT", 8080))
    log.info("Starting Flask on port %s", port)
    flask_app.run(host="0.0.0.0", port=port)
