#!/usr/bin/env python3
"""Print the current time for acknowledgement messages."""

from __future__ import annotations

import argparse
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Print the current time in a stable acknowledgement format."
    )
    parser.add_argument(
        "--timezone",
        "-z",
        default=None,
        help="IANA timezone name, for example Asia/Shanghai. Defaults to system local time.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.timezone:
        try:
            now = datetime.now(ZoneInfo(args.timezone))
        except ZoneInfoNotFoundError:
            raise SystemExit(f"Unknown timezone: {args.timezone}")
    else:
        now = datetime.now().astimezone()

    print(now.strftime("%Y-%m-%d %H:%M:%S %Z %z"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
