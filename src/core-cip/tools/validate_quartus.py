"""Reject stale FPGA builds and failing constrained timing paths."""
from pathlib import Path
import argparse,hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
def source_hashes(model='CIP01'):
    if model=='CIP':
        from prepare_family import hashes
        return hashes()
    if model=='CIP04':
        from prepare_cip04 import hashes
        return hashes()
    return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
            for directory in ['rtl','mister'] for p in sorted((ROOT/directory).iterdir())
            if p.is_file() and (directory=='rtl' or p.name in [model+'.sv','CIP01.sdc'])}
def validate(model='CIP01'):
    out=ROOT/('build/quartus' if model=='CIP01' else f'build/quartus-{model}')
    inputs=json.loads((out/'inputs.json').read_text())
    if inputs['project_sources']!=source_hashes(model):raise ValueError('FPGA build is stale: project sources changed')
    fit=(out/f'output_files/{model}.fit.summary').read_text()
    if 'Fitter Status : Successful' not in fit:raise ValueError('Fitter did not succeed')
    mapping=(out/f'output_files/{model}.map.summary').read_text()
    if 'Analysis & Synthesis Status : Successful' not in mapping:raise ValueError('Synthesis did not succeed')
    sta=(out/f'output_files/{model}.sta.summary').read_text()
    slacks=[float(s) for s in re.findall(r'^Slack\s*:\s*(-?[\d.]+)',sta,re.M)]
    if not slacks or min(slacks)<0:raise ValueError('Constrained FPGA timing failed')
    rbf=out/f'output_files/{model}.rbf'
    if not rbf.exists() or rbf.stat().st_size<1000000:raise ValueError('Missing or invalid bitstream')
    # Preparing a new build must never make an old successful bitstream look current.
    if rbf.stat().st_mtime_ns < (out/'inputs.json').stat().st_mtime_ns:
        raise ValueError('Bitstream predates this build request; compile the current sources')
    result={'status':'passed','bitstream_sha256':hashlib.sha256(rbf.read_bytes()).hexdigest(),
            'minimum_constrained_slack_ns':min(slacks),'inputs':inputs,
            'fitter_summary':fit.splitlines(),
            'qualification':inputs.get('qualification','Development build; original gate timing and comprehensive hardware validation pending.')}
    name='fpga-validation.json' if model=='CIP01' else f'{model.lower()}-fpga-validation.json'
    (ROOT/'build'/name).write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS: FPGA compilation, current source hashes and constrained timing (minimum {min(slacks):.3f} ns)')
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--model',default='CIP01',choices=['CIP','CIP01','CIP02','CIP03','CIP04']);validate(p.parse_args().model)
