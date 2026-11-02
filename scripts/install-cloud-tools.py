"""Install checksum-pinned Windows lab tools into ignored tools/, not system PATH."""
import hashlib
import io
import urllib.request
import zipfile
from pathlib import Path

TOOLS = [
    ("https://releases.hashicorp.com/terraform/1.17.1/terraform_1.17.1_windows_amd64.zip",
     "a3b71365cff94c0f978cf75d86addb075ea1bb6409055ea0ab359bf057d7898a",
     "terraform.exe", "terraform.exe"),
    ("https://get.helm.sh/helm-v4.3.1-windows-amd64.zip",
     "fcfd7b796dcf0f225abc40b5636a3b01f55f3de2fb1dfb18475df94e62c14112",
     "windows-amd64/helm.exe", "helm.exe"),
]


def main():
    root = Path(__file__).resolve().parent.parent / "tools"
    root.mkdir(exist_ok=True)
    for url, expected, member, name in TOOLS:
        with urllib.request.urlopen(url, timeout=60) as response:
            archive = response.read()
        if hashlib.sha256(archive).hexdigest() != expected:
            raise RuntimeError(f"Checksum mismatch for {name}")
        with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
            (root / name).write_bytes(zipped.read(member))
        print(f"Installed verified {name} in tools/")


if __name__ == "__main__":
    main()
