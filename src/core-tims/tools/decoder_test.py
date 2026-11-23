"""Check optimized timer arithmetic against independent integer expressions."""
from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(__file__).resolve().parents[1];shared=root/'shared/romanian'
if not shared.exists():shared=root.parent/'shared/romanian'
build=root/'build';build.mkdir(exist_ok=True);rtl=shared/'rtl/rp_i8253.sv';bench=root/'sim/timer_decode_tb.sv';binary=build/'timer-decode-test'
subprocess.run(['iverilog','-g2012','-s','timer_decode_tb','-o',str(binary),str(rtl),str(bench)],check=True)
output=subprocess.check_output(['vvp',str(binary)],text=True)
if 'PASS' not in output:raise ValueError('Timer arithmetic did not pass')
print(output.strip(),flush=True)
(build/'timer-decoder-validation.json').write_text(json.dumps({'status':'passed','encoded_values':65536,'checks':['binary reload','BCD reload','binary half-period','BCD half-period'],'sources':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [rtl,bench]}},indent=2)+'\n')
