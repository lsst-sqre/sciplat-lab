#!/usr/bin/env python3

import glob
import json
import logging
import os
from pathlib import Path

SETTINGS_DIR = (
    os.environ["HOME"]
    + "/.jupyter/lab/user-settings/@jupyterlab/notebook-extension"
)
SETTINGS_FILE = SETTINGS_DIR + "/tracker.jupyterlab-settings"
NEW_MIN = 10000
WS_DIR = os.environ["HOME"] + "/.jupyter/lab/workspaces"
WS_FILES = glob.glob(WS_DIR + "/*.jupyterlab-workspace")
logging.basicConfig()
LOGGER = logging.getLogger()


def main() -> None:
    increase_log_limit()


def increase_log_limit() -> None:
    current_contents = check_limits_file()
    new_contents = enforce_limits(current_contents)
    write_limits_file(new_contents)


def check_limits_file() -> dict:
    Path(SETTINGS_DIR).mkdir(parents=True, exist_ok=True)
    try:
        with open(SETTINGS_FILE) as f:
            return json.load(f)
    except (OSError, json.decoder.JSONDecodeError) as e:
        return {}


def enforce_limits(settings: dict) -> dict:
    current_limit = settings.get("maxNumberOutputs", 0)
    if current_limit < NEW_MIN:
        LOGGER.warning(
            f"Changing maxNumberOutputs from {current_limit} to {NEW_MIN}"
        )
        current_limit = NEW_MIN
    settings["maxNumberOutputs"] = current_limit
    return settings


def write_limits_file(settings: dict) -> None:
    with open(SETTINGS_FILE, "w") as f:
        json.dump(settings, f, sort_keys=True, indent=4)


if __name__ == "__main__":
    main()
