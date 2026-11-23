"""Boot the original HC88 ROM and exercise native disk, BASIC and cassette paths."""
from build import ROOT,BUILD,cpu,run,sources
from test_hc88_units import main as units
from validate_quartus import source_hashes
from pathlib import Path
import hashlib,json,struct,concurrent.futures,subprocess

def test_tape():
 body=b'\xf57319\x0e\x00\x00\x97\x1c\x00\x0d'
 program=b'\x00\x0a'+len(body).to_bytes(2,'little')+body
 header=b'\x00'+b'HC88 TEST '+struct.pack('<HHH',len(program),10,len(program))
 assert len(header)==17
 def record(flag,data,standard=False):
  b=bytes([flag])+data;checksum=0
  for value in b:checksum^=value
  b+=bytes([checksum])
  if standard:return b'\x10'+struct.pack('<HH',1000,len(b))+b
  return b'\x11'+struct.pack('<HHHHHHBH',2168,667,735,855,1710,1024,8,2000)+len(b).to_bytes(3,'little')+b
 tape=b'ZXTape!\x1a\x01\x14'+record(0,header)+record(255,program,True)
 out=BUILD/'hc88-test.tzx';out.write_bytes(tape);return out

def finalize(basic_prefix='hc88-runtime'):
 from check_hc88_capture import main as captures
 captures(basic_prefix)
 mode=json.loads((BUILD/(basic_prefix+'-exercise.json')).read_text())
 if mode.get('status')!='passed':raise ValueError('Native BASIC/tape/reset sequence failed')
 disk=(BUILD/'hc88-runtime-disk.dsk').read_bytes();factory=(ROOT/'assets/disks/hc88/system.dsk').read_bytes()
 if len(disk)!=len(factory) or disk[:39168]!=factory[:39168]:raise ValueError('Written disk changed the reserved boot/system tracks')
 files=(BUILD/'hc88-runtime-console.txt').read_text()
 for expected in ['B: not ready','PASS: native cylinder 79 seek/read','PASS: native BDOS create/write/close/read/compare','HC-88 persistent floppy write verified.']:
  if expected not in files:raise ValueError('Native file stage failed: '+expected)
 if json.loads((BUILD/'hc88-runtime-status.json').read_text())['sd_writes']<1:raise ValueError('No physical SD writes observed')
 if 'PASS: native cylinder 79 seek/read' not in (BUILD/'hc88-normal-console.txt').read_text():raise ValueError('Normal mechanical timing failed')
 demo=(BUILD/'hc88-runtime-0.log').read_text()
 if 'Press a key to return to CP/M.' not in demo or 'A>BASIC' not in demo:raise ValueError('Native video/sound stage did not return successfully')
 mode.update(native_cpm_files=True,persistent_floppy_write=True,native_video_sound=True,normal_spindle_and_seek=True)
 mode['project_sources']=source_hashes()
 mode['software_sources']={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'software').glob('*'))}
 mode['system_disk_sha256']=hashlib.sha256(factory).hexdigest();mode['written_disk_sha256']=hashlib.sha256(disk).hexdigest()
 mode['original_rom_sha256']=hashlib.sha256((ROOT/'assets/roms/hc88.rom').read_bytes()).hexdigest()
 (BUILD/'hc88-validation.json').write_text(json.dumps(mode,indent=2)+'\n')
 print('PASS: HC88 original boot, native CP/M files, normal seeks, runtime BASIC, cassette and reset recovery')

def main():
 run([__import__('sys').executable,ROOT/'tools/build_hc88_disk.py'])
 units();cpu()
 original_software={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'software').glob('*'))}
 original_hardware=source_hashes()
 def compile_sim(fast):
  folder=BUILD/('hc88-obj' if fast else 'hc88-normal-obj')
  run(['verilator','--cc','--exe','--build','-j','4','--top-module','hc88_sim',f'-GFAST_DISK={fast}','-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-WIDTH','-Wno-CASEINCOMPLETE','-Wno-COMBDLY','--Mdir',folder,'-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',*sources(),ROOT/'rtl/hc_family_host.sv',ROOT/'sim/hc88_sim.sv',ROOT/'sim/hc88_main.cpp'],log=f'hc88-verilator-{fast}.log')
  return folder/'Vhc88_sim'
 fast=compile_sim(1);normal=compile_sim(0);cassette=test_tape()
 commands=[[fast,'--seconds','6','--until','A>','--exercise',cassette,'--output','build/hc88-runtime'],
           [normal,'--seconds','12','--until','A>','--type','track\r','--output','build/hc88-normal']]
 def execute(pair):
  number,command=pair
  with (BUILD/f'hc88-runtime-{number}.log').open('w') as out:subprocess.run(list(map(str,command)),cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,check=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(execute,enumerate(commands)))
 if 'PASS: native cylinder 79 seek/read' not in (BUILD/'hc88-normal-console.txt').read_text():raise ValueError('Normal spindle/step timing failed')
 run([__import__('sys').executable,ROOT/'tools/check_hc88_capture.py'])
 proof=json.loads((BUILD/'hc88-runtime-exercise.json').read_text())
 if proof.get('status')!='passed':raise ValueError('HC88 native workflow failed')
 proof['normal_spindle_and_seek']=True
 proof['project_sources']=source_hashes()
 proof['software_sources']={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'software').glob('*'))}
 if proof['software_sources']!=original_software or proof['project_sources']!=original_hardware:raise ValueError('Sources changed during native HC88 tests')
 proof['system_disk_sha256']=hashlib.sha256((ROOT/'assets/disks/hc88/system.dsk').read_bytes()).hexdigest()
 proof['original_rom_sha256']=hashlib.sha256((ROOT/'assets/roms/hc88.rom').read_bytes()).hexdigest()
 (BUILD/'hc88-validation.json').write_text(json.dumps(proof,indent=2)+'\n')
 finalize()
if __name__=='__main__':main()
