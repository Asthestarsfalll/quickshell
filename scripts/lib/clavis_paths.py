"""Load the canonical Clavis Python path contract in source and release trees."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


def _load_canonical_module():
    share_or_source_root = Path(__file__).resolve().parents[2]
    candidates = (
        share_or_source_root / "packaging/clavis_paths.py",
        share_or_source_root / "libexec/clavis_paths.py",
    )
    for candidate in candidates:
        if not candidate.is_file():
            continue
        spec = importlib.util.spec_from_file_location(
            "_clavis_canonical_paths", candidate
        )
        if spec is None or spec.loader is None:
            continue
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        return module
    searched = ", ".join(str(candidate) for candidate in candidates)
    raise ImportError(f"canonical Clavis path module not found; searched: {searched}")


_canonical = _load_canonical_module()
ClavisPaths = _canonical.ClavisPaths
PathConfigurationError = _canonical.PathConfigurationError

__all__ = ["ClavisPaths", "PathConfigurationError"]
