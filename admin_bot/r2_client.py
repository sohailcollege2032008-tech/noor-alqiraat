"""
Reusable R2 upload client.
Used by both admin_bot/bot.py and admin_tools/r2_uploader.py.
"""
import boto3
from config import (
    R2_ACCOUNT_ID, R2_ACCESS_KEY_ID,
    R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME,
)


class R2Client:
    def __init__(self) -> None:
        self._s3 = boto3.client(
            "s3",
            endpoint_url=f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
            aws_access_key_id=R2_ACCESS_KEY_ID,
            aws_secret_access_key=R2_SECRET_ACCESS_KEY,
            region_name="auto",
        )
        self.bucket = R2_BUCKET_NAME

    def upload_bytes(self, data: bytes, remote_key: str) -> None:
        """Upload raw bytes to R2 under remote_key."""
        self._s3.put_object(
            Bucket=self.bucket,
            Key=remote_key,
            Body=data,
            ContentType="audio/mpeg",
        )

    def upload_file(self, local_path: str, remote_key: str) -> None:
        """Upload a local file to R2 under remote_key."""
        self._s3.upload_file(local_path, self.bucket, remote_key)

    @staticmethod
    def quran_key(riwayah: str, number: int) -> str:
        """e.g. hafs/001.mp3"""
        return f"{riwayah}/{number:03d}.mp3"

    @staticmethod
    def matn_key(matn_folder: str, number: int) -> str:
        """e.g. shatibiyyah/001.mp3"""
        return f"{matn_folder}/{number:03d}.mp3"
