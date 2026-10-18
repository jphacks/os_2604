#!/usr/bin/env python3
"""Apply the environment extension to an unmodified fixed Find Me project."""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys
source = Path(__file__).resolve().parent
project = Path(sys.argv[1]).resolve()
for name, expected in json.loads((source / 'base-hashes.json').read_text()).items():
    if hashlib.sha256((project / name).read_bytes()).hexdigest() != expected:
        raise SystemExit(f'Base differs: {name}. Use a fresh, fixed Find Me v2.3.1 project.')
subprocess.run(['patch', '-p1', '-i', str(source / 'findme-environment.patch')], cwd=project, check=True)
shutil.copytree(source / 'third_party', project / 'proj_cm33_ns/source/environment/third_party')
for name in ['environment_sensor.c', 'environment_sensor.h']:
    shutil.copy2(source / name, project / 'proj_cm33_ns/source/environment' / name)
