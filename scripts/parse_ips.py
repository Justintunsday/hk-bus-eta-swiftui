#!/usr/bin/env python3
"""Print the key fields and crashed-thread stack from an Apple .ips crash report."""
import json
import sys


def main() -> None:
    path = sys.argv[1]
    with open(path, encoding="utf-8", errors="replace") as handle:
        parts = handle.read().split("\n", 1)

    meta = json.loads(parts[0])
    try:
        payload = json.loads(parts[1])
    except json.JSONDecodeError:
        print("unparsable payload")
        return

    print("process:", meta.get("app_name"), meta.get("bug_type"))
    print("exception:", payload.get("exception"))
    print("termination:", payload.get("termination"))

    faulting = payload.get("faultingThread", 0)
    threads = payload.get("threads", [])
    images = payload.get("usedImages", [])
    if 0 <= faulting < len(threads):
        print("crashed thread frames:")
        for frame in threads[faulting].get("frames", [])[:35]:
            index = frame.get("imageIndex")
            image = images[index] if index is not None and index < len(images) else {}
            print("   ", image.get("name", "?"), frame.get("symbol", "?"), "+", frame.get("imageOffset"))


if __name__ == "__main__":
    main()
