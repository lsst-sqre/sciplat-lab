#!/usr/bin/env python3
"""
Extract package specifications from rubin-env-rsp and install each package
individually.

This is a workaround for the (we hope very rare) case of
https://github.com/lsst-sqre/sciplat-lab/actions/runs/25985290708
where conda failed to find a solution for the rubin-env-rsp metapackage,
but a rerun specifying each package individually installed just fine.
"""

from pathlib import Path
import subprocess
from typing import Any
import yaml

def _main() -> None:
    _fetch_repo()
    obj=_ingest_yaml()
    pkgs=_digest_yaml(obj)
    _print_package_specs(pkgs)


def _fetch_repo() -> None:
    """
    Download the repository.  This will need to change if we change
    feedstock repositories.
    """
    subprocess.run(
        [ "git",
          "clone",
          "https://github.com/conda-forge/rubinenv-feedstock"
         ]
    )
    

def _ingest_yaml() -> dict[str,Any]:
    """
    Read the recipe into a Python object.

    As long as the recipe stays in recipe.yaml (it changed from meta.yaml
    not that long ago), we're fine.
    """
    recipe = Path("rubinenv-feedstock") / "recipe" / "recipe.yaml"
    return yaml.safe_load(recipe.read_text())


def _digest_yaml(doc: dict[str,Any]) -> list[str]:
    """
    Extract ``rubin-env-rsp`` from the recipe and capture version constraints
    for each package.
    """
    op = doc["outputs"]
    rersp = [ x for x in op if x["package"]["name"] == "rubin-env-rsp" ][0]
    run = rersp["requirements"]["run"]
    packages = [ x for x in run if not x.startswith("$") ]
    return [ _reduce_pkg(x) for x in packages ]


def _reduce_pkg(in_spec: str) -> str:
    """
    Reformat package name and constraints for installation from the conda
    CLI.
    """
    pl = in_spec.split()
    if len(pl) < 2:
        return f"'{pl[0]}'"
    return f"'{pl[0]}{pl[1]}'"

                 
def _print_package_specs(pkgs: list[str]) -> None:
    """
    Emit the package specs to install in a form suitable for feeding to
    ``conda install`` on the command-line.
    """
    print(' '.join(pkgs))  # noqa: T201

    
if __name__ == "__main__":
    _main()
