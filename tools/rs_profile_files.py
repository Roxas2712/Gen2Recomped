"""Persistent private-profile files, excluding the HTTP worker's scratch replies."""
from pathlib import Path
import re

# Http.tmpPath('private_res'/'private_status'); older running workers use a
# Channel token rather than a random decimal suffix. Only top-level replies
# are volatile. Save/backup/tmp files elsewhere must still be compared.
HTTP_REPLY = re.compile(r'http_private_(?:res|status)_[0-9]+_(?:[0-9]+|Channel0x[0-9a-fA-F]+_[0-9]+)\.tmp')


def persistent_files(root):
    root = Path(root)
    result = {}
    for path in root.rglob('*'):
        if path.parent == root and HTTP_REPLY.fullmatch(path.name):
            continue
        assert not path.is_symlink(), path
        if path.is_file():
            result[str(path.relative_to(root))] = path
    return result
