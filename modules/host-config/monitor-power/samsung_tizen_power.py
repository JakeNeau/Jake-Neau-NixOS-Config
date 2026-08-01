import argparse
import json
from urllib.request import urlopen

from samsungtvws import SamsungTVWS


TIMEOUT = 3


def read_power_state(hostname):
    with urlopen(f"http://{hostname}:8001/api/v2/", timeout=TIMEOUT) as response:
        return json.loads(response.read())["device"]["PowerState"].lower()


def send_power_key(hostname, token_file, remote_name):
    with SamsungTVWS(
        host=hostname,
        port=8002,
        token_file=token_file,
        timeout=TIMEOUT,
        name=remote_name,
    ) as remote:
        remote.send_key("KEY_POWER")


def power_off(hostname, token_file, remote_name):
    if read_power_state(hostname) == "on":
        send_power_key(hostname, token_file, remote_name)


def power_on(hostname, token_file, remote_name):
    if read_power_state(hostname) == "standby":
        send_power_key(hostname, token_file, remote_name)


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
