#!/usr/bin/env python3

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


def main() -> None:
    current_contents = check_file()
    new_contents = enforce_limits(current_contents)
    write_file(new_contents)


def check_file() -> dict:
    Path(SETTINGS_DIR).mkdir(parents=True, exist_ok=True)
    try:
        with open(SETTINGS_FILE) as f:
            return json.load(f)
    except (OSError, json.decoder.JSONDecodeError) as e:
        return {}


def enforce_limits(settings: dict) -> dict:
    current_limit = settings.get("maxNumberOutputs", 0)
    if current_limit < NEW_MIN:
        logging.basicConfig()
        logger = logging.getLogger()
        logger.warning(
            f"Changing maxNumberOutputs from {current_limit} to {NEW_MIN}"
        )
        current_limit = NEW_MIN
    settings["maxNumberOutputs"] = current_limit
    return settings


def write_file(settings: dict) -> None:
    with open(SETTINGS_FILE, "w") as f:
        json.dump(settings, f, sort_keys=True, indent=4)


if __name__ == "__main__":
    main()
