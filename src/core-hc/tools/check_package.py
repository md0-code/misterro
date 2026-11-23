"""Verify the family package and reproduce its FPGA inputs from the source export."""
from pathlib import Path
import hashlib,json,subprocess,sys,tempfile,zipfile
from project_paths import ROOT,DOCS

def main():
    archive=ROOT/'dist/HC.zip'
    with zipfile.ZipFile(archive) as z:
        if z.testzip():raise ValueError('Invalid ZIP')
        for line in z.read('SHA256SUMS').decode().splitlines():
            expected,name=line.split('  ',1)
            if hashlib.sha256(z.read(name)).hexdigest()!=expected:raise ValueError('ZIP checksum mismatch: '+name)
        family='HC'
        cores={n for n in z.namelist() if n.startswith('_Computer/')}
        if cores!={f'_Computer/{family}.rbf'}:raise ValueError('Expected one family core')
        bundles=json.loads((DOCS/'bundles.json').read_text())
        for model,bundle in bundles.items():
            prefix=f'games/{family}/{model}/'
            actual={n[len(prefix):] for n in z.namelist() if n.startswith(prefix)}
            if actual!=set(bundle['files'])|{'bundle.json'}:raise ValueError('Wrong model media: '+model)
            receipt=json.loads(z.read(prefix+'bundle.json'))
            for name,entry in receipt['files'].items():
                if hashlib.sha256(z.read(prefix+name)).hexdigest()!=entry['sha256']:raise ValueError('Bundle checksum mismatch')
        for name in z.namelist():
            if name.startswith('source/assets/roms/') and name.endswith('.rom'):
                if bytes(int(word,16) for word in z.read(name[:-4]+'.hex').decode().split())!=z.read(name):raise ValueError('Missing or mismatched diagnostic ROM hex: '+name)
        firmware=z.read(f'games/{family}/boot.rom')
        lock=json.loads((DOCS/'sources.lock.json').read_text())['assets/roms/family.rom']
        if len(firmware)!=lock['bytes'] or hashlib.sha256(firmware).hexdigest()!=lock['sha256']:raise ValueError('Wrong combined firmware')
        with tempfile.TemporaryDirectory(prefix='family-source-',dir=ROOT/'build') as tmp:
            export=Path(tmp)
            for entry in z.infolist():
                if not entry.filename.startswith('source/'):continue
                target=export/entry.filename[len('source/'):]
                target.resolve().relative_to(export.resolve())
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(entry))
            subprocess.run([sys.executable,export/'tools/prepare_quartus.py','--model','HC'],cwd=export,check=True)
            disk=export/'assets/disks/hc88/system.dsk';before=disk.read_bytes()
            subprocess.run([sys.executable,export/'tools/build_hc88_disk.py'],cwd=export,check=True)
            if disk.read_bytes()!=before:raise ValueError('Source export does not reproduce the HC88 replacement disk')
            for script,relative in [('build_family_cpm_rom.py','assets/roms/hc-family-cpm.rom'),('pack_firmware.py','assets/roms/family.rom'),('build_hc85_blank.py','assets/disks/hc85/blank.dsk')]:
                target=export/relative;before=target.read_bytes()
                subprocess.run([sys.executable,export/'tools'/script],cwd=export,check=True)
                if target.read_bytes()!=before:raise ValueError('Source export does not reproduce '+relative)
            names=['HC.qsf' ,'HC.qpf','HC.sv','HC85.sdc','files.qip','inputs.json']
            for name in names:
                if (ROOT/f'build/quartus-{family}'/name).read_bytes()!=(export/f'build/quartus-{family}'/name).read_bytes():raise ValueError('Exported input differs: '+name)
    receipt={'status':'passed','zip_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
        'checks':['ZIP CRC and SHA256SUMS','exactly one family bitstream','all model media and combined firmware','source export reproduces FPGA settings, source hashes, combined firmware, CP/M bridge and both generated disks']}
    (ROOT/'build/package-validation.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('PASS: one family core, media completeness, ZIP checksums and source-export preparation')
if __name__=='__main__':main()
