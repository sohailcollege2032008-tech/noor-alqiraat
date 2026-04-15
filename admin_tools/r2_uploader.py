"""
Noor Al-Qira'at — R2 Edge Uploader
====================================
Supports two content hierarchies:

  Quran (2-level):    <riwayah>/<NNN>.mp3
                      e.g. hafs/001.mp3

  Mutoon (3-level):   <matn_folder>/<NNN>.mp3
                      e.g. shatibiyyah/001.mp3
                      e.g. jazariyyah/003.mp3

R2 Bucket folder structure
---------------------------
  hafs/
    001.mp3  ..  114.mp3
  warsh/
    001.mp3  ..  114.mp3
  shatibiyyah/
    001.mp3  ..  025.mp3
  jazariyyah/
    001.mp3  ..  009.mp3
  tuhfat_al_atfal/
    001.mp3  ..  003.mp3

After uploading, the Flutter app's fileAvailabilityProvider detects the
new file automatically on the next availability check.  No code change
needed unless you add a brand-new folder — in that case also add an entry
to assets/data/mutoon_index.json (for mutoon) or assets/data/quran_index.json
(for a new riwayah) and bump the app version.
"""

import os
import sys
import boto3
from dotenv import load_dotenv, find_dotenv

# ── credentials ──────────────────────────────────────────────────────────────
dotenv_path = find_dotenv()
if not dotenv_path:
    print("ERROR: .env file not found. Place it outside version control.")
    sys.exit(1)

load_dotenv(dotenv_path)

R2_ACCOUNT_ID       = os.getenv('R2_ACCOUNT_ID')
R2_ACCESS_KEY_ID    = os.getenv('R2_ACCESS_KEY_ID')
R2_SECRET_ACCESS_KEY= os.getenv('R2_SECRET_ACCESS_KEY')
R2_BUCKET_NAME      = os.getenv('R2_BUCKET_NAME')

if not all([R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME]):
    print("ERROR: Missing Cloudflare R2 credentials in .env file.")
    sys.exit(1)

s3 = boto3.client(
    's3',
    endpoint_url=f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
    aws_access_key_id=R2_ACCESS_KEY_ID,
    aws_secret_access_key=R2_SECRET_ACCESS_KEY,
    region_name='auto',
)

# ── known folders (for autocomplete hints) ────────────────────────────────────
QURAN_FOLDERS = ['hafs', 'warsh', 'qalun', 'al_duri_abi_amr']
MUTOON_FOLDERS = ['shatibiyyah', 'jazariyyah', 'tuhfat_al_atfal']

# ── helpers ───────────────────────────────────────────────────────────────────
def strip_quotes(s: str) -> str:
    for q in ('"', "'"):
        if s.startswith(q) and s.endswith(q):
            return s[1:-1]
    return s

def ask(prompt: str) -> str:
    return strip_quotes(input(prompt).strip())

def upload_single(local_path: str, destination_key: str):
    print(f"\n  Bucket : {R2_BUCKET_NAME}")
    print(f"  Remote : {destination_key}")
    confirm = ask("\nProceed? (Y/n): ").lower()
    if confirm not in ('', 'y', 'yes'):
        print("Cancelled.")
        return
    print("Uploading...")
    try:
        s3.upload_file(local_path, R2_BUCKET_NAME, destination_key)
        print(f"SUCCESS  →  {destination_key}")
    except Exception as e:
        print(f"FAILED   →  {e}")

def upload_folder(local_dir: str, remote_folder: str):
    """Batch-upload every .mp3 in local_dir, preserving 3-digit filenames."""
    files = sorted(
        f for f in os.listdir(local_dir)
        if f.lower().endswith('.mp3')
    )
    if not files:
        print("No .mp3 files found in that directory.")
        return

    print(f"\n  {len(files)} file(s) will be uploaded to  {remote_folder}/")
    for f in files:
        print(f"    {f}")
    confirm = ask("\nProceed with batch upload? (Y/n): ").lower()
    if confirm not in ('', 'y', 'yes'):
        print("Cancelled.")
        return

    ok = fail = 0
    for f in files:
        local_path = os.path.join(local_dir, f)
        # Normalize filename to 3-digit zero-padded stem
        stem = os.path.splitext(f)[0]
        try:
            key = f"{remote_folder}/{int(stem):03d}.mp3"
        except ValueError:
            key = f"{remote_folder}/{f}"   # keep as-is if not numeric
        try:
            s3.upload_file(local_path, R2_BUCKET_NAME, key)
            print(f"  OK   {key}")
            ok += 1
        except Exception as e:
            print(f"  FAIL {key}  ({e})")
            fail += 1

    print(f"\nDone: {ok} uploaded, {fail} failed.")

# ── main menu ─────────────────────────────────────────────────────────────────
def main():
    print("=" * 50)
    print("   Noor Al-Qira'at  —  R2 Edge Uploader")
    print("=" * 50)
    print("\n[1] Upload single file")
    print("[2] Batch-upload entire folder")
    mode = ask("\nChoice (1/2): ")

    if mode == '2':
        # ── batch mode ────────────────────────────────────────────────────────
        local_dir = ask("\nLocal folder containing .mp3 files: ")
        if not os.path.isdir(local_dir):
            print(f"ERROR: '{local_dir}' is not a directory.")
            return

        print("\nKnown Quran folders  : " + ", ".join(QURAN_FOLDERS))
        print("Known Mutoon folders : " + ", ".join(MUTOON_FOLDERS))
        remote_folder = ask("Remote folder name (e.g. shatibiyyah): ").lower()
        upload_folder(local_dir, remote_folder)

    else:
        # ── single-file mode ─────────────────────────────────────────────────
        local_path = ask("\nAbsolute path to audio file: ")
        if not os.path.isfile(local_path):
            print(f"ERROR: File not found at '{local_path}'")
            return

        print("\nContent type?")
        print("  [1] Quran  (riwayah folder, e.g. hafs)")
        print("  [2] Matn   (matn folder,    e.g. shatibiyyah)")
        content_type = ask("Choice (1/2): ")

        if content_type == '2':
            print("\nKnown Mutoon folders: " + ", ".join(MUTOON_FOLDERS))
            folder = ask("Matn folder (e.g. shatibiyyah): ").lower()
        else:
            print("\nKnown Quran folders: " + ", ".join(QURAN_FOLDERS))
            folder = ask("Riwayah folder (e.g. hafs): ").lower()

        raw_id = ask("Chapter/Surah number (e.g. 1 for 001.mp3): ")
        try:
            destination_key = f"{folder}/{int(raw_id):03d}.mp3"
        except ValueError:
            print("ERROR: ID must be an integer.")
            return

        upload_single(local_path, destination_key)


if __name__ == "__main__":
    main()
