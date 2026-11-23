from project_paths import ROOT
import hashlib

def harness_hashes():
 files=[p for folder in ['sim','software'] for p in sorted((ROOT/folder).rglob('*')) if p.is_file()]
 files += [ROOT/'tools'/n for n in ['sim.py','test_runtime.py','test_memory.py','test_serial.py','build_software.py','validation_inputs.py']]
 return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
