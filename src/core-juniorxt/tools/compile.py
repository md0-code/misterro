"""Compile on WSL storage, then return and validate the complete result."""
from project_paths import ROOT,DOCS
from prepare_quartus import main,OUT
from validate_quartus import validate,source_hashes
from common import run
from signoff import signoff
import argparse,json,os,shutil,tempfile
parser=argparse.ArgumentParser()
parser.add_argument("--seed",type=int,default=5,help="Quartus physical placement seed")
args=parser.parse_args()
if not 1<=args.seed<=2147483647:parser.error("seed must be a positive 31-bit integer")
main()
physical={'SEED':str(args.seed),'PHYSICAL_SYNTHESIS_EFFORT':'EXTRA','PHYSICAL_SYNTHESIS_COMBO_LOGIC_FOR_AREA':'OFF','PLACEMENT_EFFORT_MULTIPLIER':'2.0','ROUTER_TIMING_OPTIMIZATION_LEVEL':'MAXIMUM'}
with (OUT/'JUNIORXT.qsf').open('a') as f:
 for name,value in physical.items():f.write(f'\nset_global_assignment -name {name} {value}\n')
# Demand extra setup headroom on the two measured internal critical domains.
# This only tightens implementation timing; it does not change either PLL.
margin='set targets [list {emu|pll|pll_inst|altera_pll_i|cyclonev_pll|counter?0?.output_counter|divclk} {emu|pll_system_inst|pll_system_inst|altera_pll_i|general?2?.gpll~PLL_OUTPUT_COUNTER|divclk}]\nforeach target $targets {\n set clocks [get_clocks $target]\n if {[get_collection_size $clocks] != 1} {error "Missing implementation clock"}\n set_clock_uncertainty -setup -add -from $clocks -to $clocks 0.250\n}\n'
(OUT/'implementation-margin.sdc').write_text(margin)
with (OUT/'JUNIORXT.qsf').open('a') as f:f.write('\nset_global_assignment -name SDC_FILE implementation-margin.sdc\n')
inputs=json.loads((OUT/'inputs.json').read_text());inputs['implementation']={'placement_seed':args.seed,'assignments':physical,'internal_setup_margin_ns':0.250,'margin_sdc_sha256':__import__('hashlib').sha256(margin.encode()).hexdigest()}
(OUT/'inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
image=json.loads((DOCS/'dependencies.lock.json').read_text())['quartus_image'];original=source_hashes()
with tempfile.TemporaryDirectory(prefix='mister-juniorxt-quartus-') as folder:
 work=__import__('pathlib').Path(folder)
 shutil.copytree(OUT,work,dirs_exist_ok=True,ignore=shutil.ignore_patterns('db','incremental_db','output_files','greybox_tmp'))
 try:
  run(['docker','run','--rm','--network','none','--entrypoint','/opt/intelFPGA/quartus/bin/quartus_sh','-v',f'{work}:/work','-w','/work',image,'--flow','compile','JUNIORXT'],log='quartus-build.log')
  signoff(work,image)
 finally:
  changed=source_hashes()!=original
  if not changed:shutil.copytree(work,OUT,dirs_exist_ok=True)
  run(['docker','run','--rm','--network','none','--entrypoint','/bin/chown','-v',f'{work}:/cleanup',image,'-R',f'{os.getuid()}:{os.getgid()}','/cleanup'])
  if changed:raise ValueError('Hardware sources changed during compilation')
validate()
