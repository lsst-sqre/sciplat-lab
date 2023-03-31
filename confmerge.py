import configparser
import os
import shutil
import sys

def merge_ini(src: str, dest: str) -> None:
    """Merge two INI files, replacing the sections in dest with their
    equivalents in src.

    Parameters
    ----------
    src : `str`
        Path to source INI file.

    dest : `str`
        Path to destination INI file that will have ``src`` merged into it.
    """
    old_config = configparser.ConfigParser().read(dest)
    new_config = configparser.ConfigParser().read(src)
    for sect in new_config.sections():
        old_config[sect] = new_config[sect]
    with open(dest, "w") as result:
        os.chmod(dest, 0600)
        old_config.write(result)


def merge_pgpass(src: str, dest: str) -> None:
    """Merge two pgpass files, replacing the entries in dest with their
    equivalents in src.

    Parameters
    ----------
    src : `str`
        Path to source pgpass file.

    dest : `str`
        Path to destination pgpass file that will have ``src`` merged into it.
    """
    old_config = {}
    with open(dest, "r") as old:
        for line in old:
            pg, pw = line.rsplit(":", maxsplit=1)
            old_config[pg] = pw
    with open(src, "r") as new:
        for line in new:
            pg, pw = line.rsplit(":", maxsplit=1)
            old_config[pg] = pw
    with open(dest, "w") as result:
        os.chmod(dest, 0600)
        for pg, pw in old_config.iteritems():
            print(f"{pg}:{pw}", file=result)


if __name__ == "__main__":
    kind, src, dest = sys.argv[1:4]
    if not os.path.exists(dest):
        shutil.copy(src, dest)
        os.chmod(dest, 0600)
    elif kind == "ini":
        merge_ini(src, dest)
    elif kind == "pgpass":
        merge_pgpass(src, dest)
    else:
        print(f"Unrecognized file kind: {kind}", file=sys.stderr)
