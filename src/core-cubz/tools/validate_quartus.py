"""Reject stale CUB Z FPGA builds and failing constrained timing."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
def source_hashes():
 return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['rtl','mister'] for p in sorted((ROOT/folder).iterdir()) if p.is_file()}
def validate():
 out=ROOT/'build/quartus-CUBZ';inputs=json.loads((out/'inputs.json').read_text())
 if inputs['project_sources']!=source_hashes():raise ValueError('FPGA build is stale')
 fit=(out/'output_files/CUBZ.fit.summary').read_text();mapping=(out/'output_files/CUBZ.map.summary').read_text()
 if 'Fitter Status : Successful' not in fit or 'Analysis & Synthesis Status : Successful' not in mapping:raise ValueError('Compilation failed')
 sta=(out/'output_files/CUBZ.sta.summary').read_text();slacks=[float(s) for s in re.findall(r'^Slack\s*:\s*(-?[\d.]+)',sta,re.M)]
 if not slacks or min(slacks)<0:raise ValueError('Constrained FPGA timing failed')
 bitstream=out/'output_files/CUBZ.rbf'
 if not bitstream.is_file() or bitstream.stat().st_size<1000000 or bitstream.stat().st_mtime_ns<(out/'inputs.json').stat().st_mtime_ns:raise ValueError('Missing or stale bitstream')
 result={'status':'passed','bitstream_sha256':hashlib.sha256(bitstream.read_bytes()).hexdigest(),'minimum_constrained_slack_ns':min(slacks),'inputs':inputs,'fitter_summary':fit.splitlines()}
 (ROOT/'build/fpga-validation.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: current bitstream, synthesis, fitter and constrained timing',min(slacks));return result
if __name__=='__main__':validate()
