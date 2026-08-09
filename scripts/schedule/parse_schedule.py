#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
from clavis_paths import ClavisPaths


def parse_markdown(source: Path):
    if not source.is_file():
        raise FileNotFoundError(f"schedule Markdown file not found: {source}")
    lines = source.read_text(encoding="utf-8").splitlines()
    grid = []
    for line in lines:
        line = line.strip()
        if not line.startswith("|"):
            continue
        cols = [column.strip().replace("**", "") for column in line.strip("|").split("|")]
        grid.append(cols)
    if len(grid) < 3:
        raise ValueError("schedule Markdown table has fewer than three rows")

    body = grid[2:]
    rows = len(body)
    columns = len(body[0]) if rows else 0
    time_headers = [row[0] if row else "" for row in body]
    parsed_items = []
    course_colors = {}
    skipped = [[False] * columns for _ in range(rows)]
    for column in range(1, columns):
        for row in range(rows):
            if skipped[row][column]:
                continue
            text = body[row][column] if column < len(body[row]) else ""
            row_span = 1
            color_id = 0
            if text:
                while (
                    row + row_span < rows
                    and column < len(body[row + row_span])
                    and body[row + row_span][column] == text
                ):
                    skipped[row + row_span][column] = True
                    row_span += 1
                base_name = text.split("(")[0].split("（")[0].strip()
                if base_name not in course_colors:
                    course_colors[base_name] = len(course_colors)
                color_id = course_colors[base_name]
            parsed_items.append(
                {
                    "row": row,
                    "col": column - 1,
                    "rowSpan": row_span,
                    "text": text,
                    "isEmpty": not bool(text),
                    "colorId": color_id,
                }
            )
    return {"timeHeaders": time_headers, "scheduleItems": parsed_items}


def main() -> int:
    paths = ClavisPaths.from_environment()
    parser = argparse.ArgumentParser(description="Generate the Clavis schedule cache")
    parser.add_argument("--input", type=Path, default=paths.config_home / "schedule.md")
    parser.add_argument("--output", type=Path, default=paths.cache_home / "schedule.json")
    arguments = parser.parse_args()
    data = parse_markdown(arguments.input)
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = arguments.output.with_name(f".{arguments.output.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    os.replace(temporary, arguments.output)
    print(f"Schedule cache written to {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
