from project_paths import ROOT,DOCS
import hashlib,json

def collect():
 paths={'boot.rom':ROOT/'assets/boot.rom','demo.img':ROOT/'assets/demo.img','manual.img':ROOT/'software/manual.img','support/chargen.rom':ROOT/'assets/chargen.rom'}
 paths.update({'bios/bios-'+r+'.rom':ROOT/('assets/bios-'+r+'.rom') for r in ['3.0','5.0','5.0-alt']})
 sums={n:{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for n,p in paths.items()}
 manifest={'machine':'FEPER JUNIOR-XT','firmware':'boot.rom: original V4.00 (IC63 even / IC64 odd, unmodified) followed by the project Winchester ROM for the C8000 socket; bios/: original 3.0, 5.0 and 5.0-alt, which expect the PC serial board','demo':'320 KiB FAT12, 40 tracks, 2 heads, 8 sectors; FreeDOS 8086 plus native project demos','manual_disk':'MezinXT manual disk: 360 KiB booter with the 1989 technical manual, topics and tests','support':'original CHAR_RF5 2048-byte glyph EPROM; compiled into the bitstream','files':sums,'sources':json.loads((DOCS/'sources.lock.json').read_text())}
 target=ROOT/'build/bundle.json';target.write_text(json.dumps(manifest,indent=2)+'\n');paths['bundle.json']=target
 return {'games/JUNIORXT/'+n:p for n,p in paths.items()}
