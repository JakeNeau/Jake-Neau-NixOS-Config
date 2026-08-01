import importlib.util
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch


MODULE_PATH = Path(
    os.environ.get(
        "SAMSUNG_TIZEN_POWER_MODULE",
        Path(__file__).with_name("samsung_tizen_power.py"),
    )
)
SPEC = importlib.util.spec_from_file_location("samsung_tizen_power", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

HOSTNAME = "monitor.example.test"
TOKEN_FILE = "/run/secrets/testSamsungTizenToken"
REMOTE_NAME = "test-monitor-power"


class Response:
    def __init__(self, power_state):
        self.payload = json.dumps({"device": {"PowerState": power_state}}).encode()

    def __enter__(self):
        return self

    def __exit__(self, _exception_type, _exception, _traceback):
        return None

    def read(self):
        return self.payload


class SamsungTizenPowerTest(unittest.TestCase):
    @patch.object(MODULE, "urlopen")
    def test_reads_power_state_from_configured_monitor(self, urlopen):
        urlopen.return_value = Response("on")

        self.assertEqual(MODULE.read_power_state(HOSTNAME), "on")
        urlopen.assert_called_once_with(
            f"http://{HOSTNAME}:8001/api/v2/",
            timeout=MODULE.TIMEOUT,
        )

    @patch.object(MODULE, "SamsungTVWS")
    @patch.object(MODULE, "read_power_state", return_value="on")
    def test_power_off_sends_power_key_when_monitor_is_on(self, _read_power_state, samsung_tv):
        remote = samsung_tv.return_value.__enter__.return_value

        MODULE.power_off(HOSTNAME, TOKEN_FILE, REMOTE_NAME)

        samsung_tv.assert_called_once_with(
            host=HOSTNAME,
            port=8002,
            token_file=TOKEN_FILE,
            timeout=MODULE.TIMEOUT,
            name=REMOTE_NAME,
        )
        remote.send_key.assert_called_once_with("KEY_POWER")

    @patch.object(MODULE, "SamsungTVWS")
    @patch.object(MODULE, "read_power_state", return_value="standby")
    def test_power_off_does_not_toggle_a_standby_monitor_on(self, _read_power_state, samsung_tv):
        MODULE.power_off(HOSTNAME, TOKEN_FILE, REMOTE_NAME)

        samsung_tv.assert_not_called()

    @patch.object(MODULE, "SamsungTVWS")
    @patch.object(MODULE, "read_power_state", return_value="standby")
    def test_power_on_sends_power_key_when_monitor_is_standby(self, _read_power_state, samsung_tv):
        remote = samsung_tv.return_value.__enter__.return_value

        MODULE.power_on(HOSTNAME, TOKEN_FILE, REMOTE_NAME)

        remote.send_key.assert_called_once_with("KEY_POWER")

    @patch.object(MODULE, "SamsungTVWS")
    @patch.object(MODULE, "read_power_state", return_value="on")
    def test_power_on_does_not_toggle_an_on_monitor_off(self, _read_power_state, samsung_tv):
        MODULE.power_on(HOSTNAME, TOKEN_FILE, REMOTE_NAME)

        samsung_tv.assert_not_called()


if __name__ == "__main__":
    unittest.main()
