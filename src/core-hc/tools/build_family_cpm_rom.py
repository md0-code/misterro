"""Bridge the resident BASIC launcher to the original Rev-E CP/M F800 entry."""
from project_paths import ROOT

def main():
 folder=ROOT/'assets/roms'
 # Original v1 entry copies its payload to 8000 before changing ROM placement.
 bootstrap=bytearray((folder/'hc2000-1.rom').read_bytes()[:30]+b'\xff'*(8192-30))
 # Set SP, then use the original Rev-E BASIC trampoline: OUT 7E,3; JP F800.
 bootstrap[30:40]=bytes.fromhex('31 00 80 3e 03 d3 7e c3 00 f8')
 bios=(folder/'hc-family-cpm-bios.rom').read_bytes()
 if len(bios)!=8192:raise ValueError('Wrong original Rev-E BIOS size')
 (folder/'hc-family-cpm.rom').write_bytes(bootstrap+bios)
if __name__=='__main__':main()
