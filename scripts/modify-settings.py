#!/usr/bin/env python3
"""Entrypoint to override JupyterLab settings with Rubin-specific policy."""

import argparse
import json
import sys
from pathlib import Path
from typing import Any

DEFAULT_OVERRIDES = Path(
    "/usr/local/etc/jupyter/labconfig/default_setting_overrides.json"
)
DEFAULT_RUBIN_SITE_POLICY = {
    # Subshells have some race condition that makes them behave badly with
    # matplotlib.
    # https://github.com/matplotlib/ipympl/issues/609
    "@jupyterlab/apputils-extension:kernels-settings": {
        "commsOverSubshells": "disabled"
    },
    # Large notebooks may not render correctly with windowingMode: full.
    # https://github.com/jupyter/jupyterlab/issues/17023
    "@jupyterlab/notebook-extension:tracker": {
        "windowingMode": "defer",
    },
    # Make checking spelling in comments opt-in rather than opt-out.
    "@jupyterlab-contrib/spellchecker:plugin": {
        "checkComments": False,
    },
    # Default viewer for markdown should be the previewer
    # For rendering CST landing page correctly.
    "@jupyterlab/docmanager-extension:plugin": {
        "defaultViewers": {
            "markdown": "Markdown Preview"
        },
    },
}

class SettingsModifier:
    """Settings Modifier for user labs.

    Parameters
    ----------
    overrides
        Full path of ``overrides.json``.
    """

    def __init__(
        self,
        overrides: Path | None,
        policy: Path|None = None
    )  -> None:
        self._overrides = overrides or DEFAULT_OVERRIDES
        self._settings: dict[str, Any] = {}
        if self._overrides.exists():
            self._settings = json.loads(self._overrides.read_text())
        if policy is None:
            self._policy = DEFAULT_RUBIN_SITE_POLICY
        else:
            self._policy = json.loads(policy.read_text())

    def modify_settings(self) -> None:
        """Modify settings according to site policy."""
        self._settings.update(self._policy)

    def write_settings(self) -> None:
        """Write ``override.json`` if any override settings exist; remove it
        if they do not and the file is present."""
        if self._settings:
            self._overrides.write_text(json.dumps(self._settings))
            return
        if self._overrides.exists():
            self._overrides.unlink()

def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog=sys.argv[0],
        description="Override JupyterLab settings according to policy",
    )
        
    parser.add_argument("--overrides", "-o",
                        help="Location of ``overrides.json``")
    parser.add_argument("--policy", "-p",
                        help="Location of policy JSON file")
    return parser.parse_args()

            
def _main() -> None:
    """Entrypoint."""
    args = _parse_args()
    overrides = None
    if args.overrides:
        overrides=Path(args.overrides)
    policy = None
    if args.policy:
        policy=Path(args.policy)
    modifier = SettingsModifier(overrides=overrides, policy=policy)
    modifier.modify_settings()
    modifier.write_settings()


if __name__ == "__main__":
    _main()
