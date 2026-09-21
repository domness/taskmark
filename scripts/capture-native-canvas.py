#!/usr/bin/env python3
"""Capture opt-in native test windows from the authorized terminal process.

Usage: python3 scripts/capture-native-canvas.py /existing/output/directory
Requires Screen Recording permission for the process hosting this command.
"""

import os
from pathlib import Path
import re
import subprocess
import sys

destination = Path(sys.argv[1]).resolve(strict=True)
environment = os.environ | {
    "TEST_RUNNER_TASKMARK_CANVAS_CAPTURES": str(destination),
}
command = [
    "xcodebuild", "-project", "LocalTodo.xcodeproj", "-scheme", "LocalTodoApp",
    "-configuration", "Debug", "-destination", "platform=macOS", "test",
    "CODE_SIGNING_ALLOWED=NO", "-only-testing:LocalTodoAppTests/FocusedCanvasTests",
]
captured = []
with subprocess.Popen(command, env=environment, stdout=subprocess.PIPE,
                      stderr=subprocess.STDOUT, text=True, bufsize=1) as process:
    for line in process.stdout:
        print(line, end="", flush=True)
        match = re.search(r"TASKMARK_CAPTURE (\d+) ([\w-]+)", line)
        if match:
            number, name = match.groups()
            subprocess.run([
                "/usr/sbin/screencapture", "-x", "-o", "-l", number,
                str(destination / f"{name}.png"),
            ], check=True)
            captured.append(name)
    result = process.wait()
if result or len(captured) != 4:
    raise SystemExit(f"Capture incomplete: xcodebuild={result}, images={captured}")
