"""Package the verified family core, every model's media and corresponding sources."""
from pathlib import Path
import hashlib,json,zipfile
from project_paths import ROOT,DOCS,PLAN,export_readme
from validate_quartus import validate,source_hashes
from bundles import collect,source_files
from prepare_family import hashes

def main():
    validate('CIP')
    proof=json.loads((ROOT/'build/family-validation.json').read_text())
    if proof['status']!='passed' or proof['project_sources']!=hashes():raise ValueError('Run current family tests before packaging')
    files={'_Computer/CIP.rbf':ROOT/'build/quartus-CIP/output_files/CIP.rbf',
           'README.md':export_readme(),'docs/family-validation.json':ROOT/'build/family-validation.json',
           'docs/fpga-validation.json':ROOT/'build/cip-fpga-validation.json'}
    files.update(collect());files.update(source_files())
    # Fixed-model diagnostics initialize their ROMs from hex, while the family
    # host uploads binary banks. Export both representations of every ROM.
    hex_dir=ROOT/'build/package-romhex';hex_dir.mkdir(exist_ok=True)
    for name,path in list(files.items()):
        if name.startswith('source/assets/roms/') and name.endswith('.rom'):
            target=hex_dir/(path.stem+'.hex')
            target.write_text(''.join(f'{byte:02x}\n' for byte in path.read_bytes()))
            files[name[:-4]+'.hex']=target
    for folder in ['rtl','mister','tools','sim']:
        for p in sorted((ROOT/folder).rglob('*')):
            if p.is_file() and '__pycache__' not in p.parts:files['source/'+p.relative_to(ROOT).as_posix()]=p
    for p in sorted(DOCS.rglob('*')):
        rel=p.relative_to(DOCS)
        if not p.is_file() or any(x in ['reference','analysis','__pycache__'] for x in rel.parts):continue
        if len(rel.parts)==1 and p.name=='PLAN.md':continue
        files['docs/'+rel.as_posix()]=p;files['source/docs/'+rel.as_posix()]=p
    for folder in ['sys', 'rtl', 'tools', 'savestates_rom']:
        for p in sorted((ROOT/'vendor/spectrum'/folder).rglob('*')):
            if p.is_file():files['source/vendor/spectrum/'+p.relative_to(ROOT/'vendor/spectrum').as_posix()]=p
    for name in ['ZX-Spectrum.qsf', 'ZX-Spectrum.sdc', 'ZX-Spectrum.sv', 'files.qip', 'README.md']:
        files['source/vendor/spectrum/'+name]=ROOT/'vendor/spectrum'/name
    for name,entry in json.loads((DOCS/'sources.lock.json').read_text()).items():
        if name.startswith('assets/tapes/') and name.endswith('.tzx'):files['source/'+name]=ROOT/name
    files['source/README.md']=export_readme()
    files['source/assets/tapes/CipBas.mp3']=ROOT/'assets/tapes/CipBas.mp3'
    output=ROOT/'dist/CIP.zip';output.parent.mkdir(exist_ok=True)
    manifest={name:hashlib.sha256(p.read_bytes()).hexdigest() for name,p in files.items()}
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
        for name,p in files.items():z.write(p,name)
        z.writestr('SHA256SUMS',''.join(f'{digest}  {name}\n' for name,digest in sorted(manifest.items())))
    with zipfile.ZipFile(output) as z:
        if z.testzip():raise ValueError('ZIP integrity failure')
        for name,digest in manifest.items():
            if hashlib.sha256(z.read(name)).hexdigest()!=digest:raise ValueError('ZIP checksum mismatch: '+name)
    digest=hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{digest}  {output.name}\n')
    print(output,output.stat().st_size,digest)
if __name__=='__main__':main()
