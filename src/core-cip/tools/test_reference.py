"""Check original-clock tape reception independently of the reduced-clock long run."""
from pathlib import Path
import argparse,hashlib,json
from validate_quartus import source_hashes
from build import ROOT,BUILD,run,sources,cpu
def main():
    from test_family import expected_basic
    BUILD.mkdir(exist_ok=True);expected_basic()
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check-only',action='store_true');args=p.parse_args()
    if not args.check_only:
        cpu()
        run(['verilator','--cc','--exe','--build','-j','4','--top-module','cip01_sim','-GCLOCK_STEP=1',
        '-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-CASEINCOMPLETE','-Wno-WIDTH','-Wno-COMBDLY',
        '--Mdir',BUILD/'reference-obj','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',
        '-CFLAGS','-DREFERENCE_CLOCK',
        *sources(),ROOT/'sim/cip01_sim.sv',ROOT/'sim/cip01_main.cpp'],log='reference-build.log')
        run([BUILD/'reference-obj/Vcip01_sim','--seconds','.6','--tape',ROOT/'assets/tapes/basic.tzx','--tape-seconds','16'],log='reference-runtime.log')
    expected=(BUILD/'expected-basic.bin').read_bytes();actual=(BUILD/'reference-loaded.bin').read_bytes()
    n=next((i for i,(a,b) in enumerate(zip(expected,actual)) if a!=b),len(expected))
    if n<500:raise ValueError(f'Original-clock tape reception failed at BASIC byte {n}')
    (BUILD/'reference-validation.json').write_text(json.dumps({'status':'passed','project_sources':source_hashes(),
        'master_hz':56000000,'tape_seconds':17,'verified_basic_prefix_bytes':n,
        'payload_sha256':hashlib.sha256(expected).hexdigest(),
        'capture_sha256':hashlib.sha256(actual).hexdigest()},indent=2)+'\n')
    print(f'PASS: original 56 MHz scheduler received {n} consecutive correct BASIC bytes through EAR')
if __name__=='__main__':main()
