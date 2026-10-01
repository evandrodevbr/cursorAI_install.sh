"""Offline regression tests; no installer, network or package manager is run."""
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "cursor-ai.sh"


class DownloadTests(unittest.TestCase):
    def run_shell(self, body):
        result = subprocess.run(
            ["bash", "--noprofile", "--norc", "-c", 'source "$1"\nsleep() { :; }\n' + body, "test", str(SCRIPT)],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_http_error_does_not_replace_existing_download(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "cursor.AppImage"
            output.write_text("working version")
            self.run_shell('''
curl() {
    local arg fail=false out=""
    while (($#)); do
        arg=$1; shift
        case "$arg" in --fail) fail=true;; -o) out=$1; shift;; esac
    done
    printf 'HTTP error page' > "$out"
    if "$fail"; then return 22; fi
}
if download_with_progress example.invalid "$2" "test"; then exit 9; fi
'''.replace('"$2"', '"' + str(output) + '"'))
            self.assertEqual(output.read_text(), "working version")

    def test_package_destination_inside_temp_directory(self):
        self.run_shell('''
curl() {
    while (($#)); do
        if [[ $1 == -o ]]; then printf 'package bytes' > "$2"; return 0; fi
        shift
    done
    return 1
}
download_with_progress example.invalid "${TEMP_DIR}/cursor.deb" "package"
[[ $(cat "${TEMP_DIR}/cursor.deb") == 'package bytes' ]]
''')

    def test_empty_response_is_rejected(self):
        self.run_shell('''
curl() { return 0; }
if download_with_progress example.invalid "${TEMP_DIR}/cursor.rpm" "empty"; then exit 9; fi
[[ ! -e "${TEMP_DIR}/cursor.rpm" ]]
''')

    def test_url_lookup_rejects_http_error_even_if_curl_prints_a_url(self):
        self.run_shell('''
curl() { printf 'https://example.invalid/error'; return 22; }
if get_download_url appimage x64; then exit 9; fi
''')

    def test_move_failure_is_reported(self):
        self.run_shell('''
curl() {
    while (($#)); do
        if [[ $1 == -o ]]; then printf 'package bytes' > "$2"; return 0; fi
        shift
    done
}
mv() { return 1; }
if download_with_progress example.invalid "${TEMP_DIR}/cursor.rpm" "test"; then exit 9; fi
''')


if __name__ == "__main__":
    unittest.main()
