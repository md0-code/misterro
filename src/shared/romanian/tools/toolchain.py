"""Shared, pinned native-machine simulation and FPGA build tools."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,tempfile

def digest(paths,root):return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
def main(root,shared):
 global ROOT,SHARED,BUILD,UP,PROFILE,DEP
 ROOT=root;SHARED=shared;BUILD=ROOT/'build';BUILD.mkdir(exist_ok=True)
 UP=ROOT/'vendor/spectrum'
 if not UP.exists():UP=ROOT.parent/'core-hc/vendor/spectrum'
 PROFILE=json.loads((ROOT/'mister/profile.json').read_text())
 doc=ROOT/'docs/dependencies.lock.json'
 if not doc.exists():doc=ROOT.parent.parent/'docs'/ROOT.name[5:]/'dependencies.lock.json'
 DEP=json.loads(doc.read_text())
 p=argparse.ArgumentParser();p.add_argument('action',choices=['sim','test','diagnose','lint','quartus','package','assets','fetch']);args,extra=p.parse_known_args()
 if args.action in ['assets','fetch']:
  import assets
  (assets.fetch if args.action=='fetch' else assets.verify)(ROOT);return
 if args.action=='package':
  import package
  package.main(ROOT,SHARED,hashes());return
 if args.action in ['sim','lint','test','diagnose']:
  cpu();files=sources()+[BUILD/'t80.v']
  cmd=['verilator','--top-module','machine_core','-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-WIDTH','-Wno-CASEINCOMPLETE','-I'+str(SHARED/'rtl')]
  if args.action=='lint':run(cmd+['--lint-only',*files]);return
  obj=BUILD/('release-obj' if args.action=='test' else 'test-obj' if args.action=='diagnose' else 'obj')
  original=hashes(native=True);harness=digest(sorted((SHARED/'sim').glob('*')),SHARED)
  run(cmd+['--cc','--exe','--build','-j','6','--Mdir',obj,'-CFLAGS',f'-O3 -DMACHINE_CLOCK={PROFILE["clock_hz"]} -DROM_BYTES={PROFILE["firmware_bytes"]} -DHAS_SDRAM={int(PROFILE["requires_sdram"])} -DNATIVE_ASCII={(2 if PROFILE["name"]=="PRAE" else int(PROFILE["name"]=="AMIC"))}','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',*files,SHARED/'sim/main.cpp'],BUILD/'verilator-build.log')
  if hashes(native=True)!=original or digest(sorted((SHARED/'sim').glob('*')),SHARED)!=harness:raise ValueError('Simulator sources changed during build')
  (BUILD/'simulator-build.json').write_text(json.dumps({'inputs':original,'harness':harness,'binary':str((obj/'Vmachine_core').relative_to(ROOT)),'binary_sha256':hashlib.sha256((obj/'Vmachine_core').read_bytes()).hexdigest()},indent=2)+'\n')
  if args.action in ['test','diagnose']:
   import runtime_tests
   runtime_tests.main(ROOT,SHARED,PROFILE,lambda:hashes(native=True),diagnostic_only=args.action=='diagnose');return
  run([BUILD/'obj/Vmachine_core',*extra]);return
 if args.action=='quartus':quartus();return
 raise ValueError('Unknown build action')

def run(cmd,log=None,**kwargs):
 print('+ '+' '.join(map(str,cmd)),flush=True)
 if log:
  with log.open('w') as f:r=subprocess.run(list(map(str,cmd)),cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,**kwargs)
  if r.returncode:print('\n'.join(log.read_text(errors='replace').splitlines()[-70:]));raise subprocess.CalledProcessError(r.returncode,cmd)
 else:subprocess.run(list(map(str,cmd)),cwd=ROOT,check=True,**kwargs)

def sources():
 names={'AMIC':['rp_native_machine','rp_native_keyboard','rp_mono_video','rp_keys','rp_i8255','rp_i8251','rp_tape'],
 'PRAE':['rp_native_machine','rp_native_keyboard','rp_mono_video','rp_keys','rp_i8255','rp_i8251','rp_tape'],
 'JET':['rp_spectrum_keyboard','rp_spectrum_video','rp_keys','rp_tape'],
 'COBRA':['rp_spectrum_keyboard','rp_cobra_video','rp_keys','rp_i8255','rp_u765','rp_z80ctc','rp_tape'],
 'TIMS':['rp_spectrum_keyboard','rp_keys','rp_i8255','rp_i8251','rp_i8253','rp_u765','rp_tape','rp_tims_video','rp_ay','rp_sdram','rp_sdram_host','rp_printer_spool']}[PROFILE['name']]
 return sorted((ROOT/'rtl').glob('*.sv'))+[SHARED/'rtl'/(n+'.sv') for n in names]
def hashes(native=False):
 paths=sorted((ROOT/'rtl').glob('*'))+([ROOT/'mister/profile.json'] if native else sorted((ROOT/'mister').glob('*')))
 local=digest(paths,ROOT)
 common=digest([p for p in sources() if p.parent==SHARED/'rtl']+list((SHARED/'rtl').glob('*.vh')),SHARED)
 return {**local,**{'shared/'+k:v for k,v in common.items()}}
def cpu():
 files=['T80_Pack','T80_ALU','T80_MCode','T80_Reg','T80','T80pa'];vhdl=[UP/f'rtl/T80/{f}.vhd' for f in files]
 fingerprint=hashlib.sha256((DEP['ghdl_image']+'-v5').encode()+b''.join(p.read_bytes() for p in vhdl)).hexdigest();stamp=BUILD/'vhdl.sha256';target=BUILD/'t80.v'
 if stamp.exists() and stamp.read_text()==fingerprint and target.exists():return
 cache=ROOT.parent/'core-cubz/build'
 if (cache/'vhdl.sha256').exists() and (cache/'vhdl.sha256').read_text()==fingerprint:shutil.copyfile(cache/'t80.v',target)
 else:
  generated=BUILD/'vhdl';generated.mkdir(exist_ok=True)
  for path in vhdl:
   t=re.sub(r'(?im)^(\s*)(\w+)(\s*:\s*T80\w*\s*)$',r'\1\2_component\3',path.read_text());(generated/path.name).write_text(t)
  cmd=['docker','run','--rm','--network','none','--entrypoint','ghdl','-v',f'{ROOT}:/work','-w','/work',DEP['ghdl_image'],'--synth','--std=08','-fsynopsys','--out=verilog',*[f'build/vhdl/{f}.vhd' for f in files],'-e','T80pa']
  t=subprocess.check_output(cmd,cwd=ROOT).decode();t=re.sub(r'\bdo\b','data_out',t);t=re.sub(r'(output \[211:0\] )reg\b',r'\1registers_out',t);t=re.sub(r'\bassign reg\b','assign registers_out',t).replace('.reg(','.registers_out(');target.write_text(t)
 stamp.write_text(fingerprint)

def quartus():
 name=PROFILE['name'];out=BUILD/('quartus-'+name);out.mkdir(exist_ok=True)
 if (UP/'.git').exists():
  revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=UP,text=True).strip()
  if revision!=DEP['spectrum']['commit']:raise ValueError('Dependency revision changed')
 else:
  for dependency_file,expected in json.loads((UP/'export-sha256.json').read_text()).items():
   if hashlib.sha256((UP/dependency_file).read_bytes()).hexdigest()!=expected:raise ValueError('Dependency export changed: '+dependency_file)
 shutil.copytree(UP/'sys',out/'sys',dirs_exist_ok=True);shutil.copytree(UP/'rtl/T80',out/'rtl/T80',dirs_exist_ok=True)
 (out/'rtl/pll.qip').write_text('# Native machine clock.\n')
 for p in sources():shutil.copyfile(p,out/'rtl'/p.name)
 for tape_file in ['tape.sv','pzxplayer.sv','tzxplayer.vhd']:shutil.copyfile(UP/'rtl'/tape_file,out/'rtl'/tape_file)
 for p in (SHARED/'rtl').glob('*.vh'):shutil.copyfile(p,out/'rtl'/p.name)
 for p in (ROOT/'mister').glob('*'):
  if p.is_file():shutil.copyfile(p,out/p.name)
 settings=(UP/'ZX-Spectrum.qsf').read_text().replace('17.0.2 Standard Edition','17.0.2 Lite Edition').replace('set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL\n','')+'\nset_global_assignment -name NUM_PARALLEL_PROCESSORS 4\n'
 (out/(name+'.qsf')).write_text(settings);(out/(name+'.qpf')).write_text('QUARTUS_VERSION = "17.0"\nPROJECT_REVISION = "'+name+'"\n')
 lines=['set_global_assignment -name QIP_FILE rtl/T80/T80.qip','set_global_assignment -name SYSTEMVERILOG_FILE rtl/tape.sv','set_global_assignment -name SYSTEMVERILOG_FILE rtl/pzxplayer.sv','set_global_assignment -name VHDL_FILE rtl/tzxplayer.vhd']+['set_global_assignment -name SYSTEMVERILOG_FILE rtl/'+p.name for p in sources()]+['set_global_assignment -name SYSTEMVERILOG_FILE '+name+'.sv','set_global_assignment -name SYSTEMVERILOG_FILE rp_pll.sv','set_global_assignment -name SDC_FILE machine.sdc']
 (out/'files.qip').write_text('\n'.join(lines)+'\n');original=hashes();(out/'inputs.json').write_text(json.dumps(original,indent=2)+'\n')
 with tempfile.TemporaryDirectory(prefix='mister-'+name.lower()+'-') as folder:
  work=Path(folder);shutil.copytree(out,work,dirs_exist_ok=True,ignore=shutil.ignore_patterns('db','incremental_db','output_files','greybox_tmp'))
  try:run(['docker','run','--rm','--network','none','--entrypoint','/opt/intelFPGA/quartus/bin/quartus_sh','-v',f'{work}:/work','-w','/work',DEP['quartus_image'],'--flow','compile',name],BUILD/'quartus-build.log')
  finally:
   if hashes()==original:shutil.copytree(work,out,dirs_exist_ok=True)
   run(['docker','run','--rm','--network','none','--entrypoint','/bin/chown','-v',f'{work}:/cleanup',DEP['quartus_image'],'-R',f'{os.getuid()}:{os.getgid()}','/cleanup'])
   if hashes()!=original:raise ValueError('Hardware changed during build')
 fit=(out/f'output_files/{name}.fit.summary').read_text();mapping=(out/f'output_files/{name}.map.summary').read_text();sta=(out/f'output_files/{name}.sta.summary').read_text()
 slacks=[float(s) for s in re.findall(r'^Slack\s*:\s*(-?[\d.]+)',sta,re.M)];rbf=out/f'output_files/{name}.rbf'
 if 'Fitter Status : Successful' not in fit or 'Analysis & Synthesis Status : Successful' not in mapping or not slacks or min(slacks)<0 or not rbf.exists():raise ValueError('FPGA compilation or constrained timing failed')
 (BUILD/'fpga-validation.json').write_text(json.dumps({'status':'passed','inputs':original,'rbf_sha256':hashlib.sha256(rbf.read_bytes()).hexdigest(),'minimum_constrained_slack_ns':min(slacks),'fitter_summary':fit.splitlines()},indent=2)+'\n');print('PASS FPGA',name,min(slacks),flush=True)
