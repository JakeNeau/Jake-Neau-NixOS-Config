import argparse
import json
import os
import socket
import time
from pathlib import Path
from urllib.request import urlopen

from samsungtvws import SamsungTVWS

STATE_TIMEOUT = 1
REMOTE_TIMEOUT = 3
POWER_ON_TIMEOUT = 30
POWER_ON_RETRY_DELAY = 0.5


def read_power_state(hostname):
    with urlopen(f"http://{hostname}:8001/api/v2/", timeout=STATE_TIMEOUT) as response:
        return json.loads(response.read())["device"]["PowerState"].lower()


def address_cache_path(remote_name):
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    return cache_home / "monitor-power" / f"{remote_name}.address"


def resolve_and_cache_address(hostname, remote_name):
    address = socket.gethostbyname(hostname)
    path = address_cache_path(remote_name)

    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"{address}\n")
    except OSError:
        pass

    return address


def read_cached_address(remote_name):
    try:
        return address_cache_path(remote_name).read_text().strip() or None
    except OSError:
        return None


def read_power_state_with_retry(hostname):
    deadline = time.monotonic() + POWER_ON_TIMEOUT

    while True:
        try:
            return read_power_state(hostname)
        except OSError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(POWER_ON_RETRY_DELAY)


def send_power_key(hostname, token_file, remote_name):
    with SamsungTVWS(
        host=hostname,
        port=8002,
        token_file=token_file,
        timeout=REMOTE_TIMEOUT,
        name=remote_name,
    ) as remote:
        remote.send_key("KEY_POWER")


def power_off(hostname, token_file, remote_name):
    address = resolve_and_cache_address(hostname, remote_name)
    if read_power_state(address) == "on":
        send_power_key(address, token_file, remote_name)


def power_on(hostname, token_file, remote_name):
    address = read_cached_address(remote_name) or hostname
    if read_power_state_with_retry(address) == "standby":
        send_power_key(address, token_file, remote_name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hostname", required=True)
    parser.add_argument("--token-file", required=True)
    parser.add_argument("--remote-name", required=True)
    parser.add_argument("action", choices=("on", "off"))
    arguments = parser.parse_args()

    power = power_on if arguments.action == "on" else power_off
    power(arguments.hostname, arguments.token_file, arguments.remote_name)


if __name__ == "__main__":
    main()
