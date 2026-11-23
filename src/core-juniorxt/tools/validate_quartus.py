"""Reject stale JUNIOR-XT FPGA builds and failing constrained timing."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
def source_hashes():
 files=[p for folder in ['rtl','mister'] for p in sorted((ROOT/folder).iterdir()) if p.is_file()]
 files += [ROOT/'tools'/n for n in ['prepare_assets.py','prepare_quartus.py']]
 docs=ROOT.parent.parent/'docs/juniorxt' if (ROOT.parent.parent/'docs/juniorxt').exists() else ROOT/'docs'
 files += [docs/'dependencies.lock.json',docs/'sources.lock.json']
 return {(('docs/'+p.name) if p.parent==docs else p.relative_to(ROOT).as_posix()):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}

def validate():
 out=ROOT/'build/quartus-JUNIORXT';inputs=json.loads((out/'inputs.json').read_text())
 if inputs['project_sources']!=source_hashes():raise ValueError('FPGA build is stale')
 if (out/'rtl/video/cga.hex').read_bytes()!=(ROOT/'assets/cga.hex').read_bytes():raise ValueError('FPGA character ROM differs from the native asset')
 mapping_report=(out/'output_files/JUNIORXT.map.rpt').read_text()
 if 'rtl/video/cga.hex' not in mapping_report or 'rtl/8088/mcl86_ucode.mem' not in mapping_report:raise ValueError('Missing synthesized font or CPU microcode')
 physical=inputs.get('implementation',{})
 for name,value in physical.get('assignments',{}).items():
  if f'set_global_assignment -name {name} {value}' not in (out/'JUNIORXT.qsf').read_text():raise ValueError('Missing physical optimization: '+name)
 if physical.get('margin_sdc_sha256') and hashlib.sha256((out/'implementation-margin.sdc').read_bytes()).hexdigest()!=physical['margin_sdc_sha256']:raise ValueError('Implementation setup margin changed')
 seed=physical.get('placement_seed',5)
 if f'set_global_assignment -name SEED {seed}' not in (out/'JUNIORXT.qsf').read_text():raise ValueError('Missing physical placement seed')
 fit_report=(out/'output_files/JUNIORXT.fit.rpt').read_text(encoding='latin1')
 if not re.search(r'Fitter Initial Placement Seed\s*;\s*'+str(seed)+r'\s*;',fit_report):raise ValueError('Fitter seed differs from build inputs')
 fit=(out/'output_files/JUNIORXT.fit.summary').read_text();mapping=(out/'output_files/JUNIORXT.map.summary').read_text()
 if 'Fitter Status : Successful' not in fit or 'Analysis & Synthesis Status : Successful' not in mapping:raise ValueError('Compilation failed')
 signoff=json.loads((out/'signoff.json').read_text())
 fit_qsf=(out/'JUNIORXT.fit.qsf').read_text();baseline_qsf=(out/'JUNIORXT.qsf').read_text()
 from signoff import LINE
 if fit_qsf.count(LINE)!=1 or baseline_qsf!=fit_qsf.replace(LINE,'# Fitter-only extra margin; baseline signoff uses the original SDC files.'):raise ValueError('Baseline constraints differ from the fitted design')
 for name,key in [('JUNIORXT.fit.qsf','fit_qsf_sha256'),('JUNIORXT.qsf','baseline_qsf_sha256'),('output_files/JUNIORXT.sta.summary','sta_summary_sha256'),('output_files/JUNIORXT.rbf','bitstream_sha256')]:
  if hashlib.sha256((out/name).read_bytes()).hexdigest()!=signoff[key]:raise ValueError('Signoff artifact changed: '+name)
 sta=(out/'output_files/JUNIORXT.sta.summary').read_text();slacks=[float(s) for s in re.findall(r'^Slack\s*:\s*(-?[\d.]+)',sta,re.M)]
 if not slacks or min(slacks)<0:raise ValueError('Constrained FPGA timing failed')
 bitstream=out/'output_files/JUNIORXT.rbf'
 if not bitstream.is_file() or bitstream.stat().st_size<1000000 or bitstream.stat().st_mtime_ns<(out/'inputs.json').stat().st_mtime_ns:raise ValueError('Missing or stale bitstream')
 result={'status':'passed','bitstream_sha256':hashlib.sha256(bitstream.read_bytes()).hexdigest(),'minimum_constrained_slack_ns':min(slacks),'inputs':inputs,'signoff':signoff,'fitter_summary':fit.splitlines()}
 (ROOT/'build/fpga-validation.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: current bitstream, synthesis, fitter and constrained timing',min(slacks));return result
if __name__=='__main__':validate()
