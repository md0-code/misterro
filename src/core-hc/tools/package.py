"""Package the verified family core, every model's media and corresponding sources."""
from pathlib import Path
import hashlib,json,zipfile
from project_paths import ROOT,DOCS,PLAN,export_readme
from validate_quartus import validate,source_hashes
from bundles import collect,source_files

def main():
    validate('HC')
    proof=json.loads((ROOT/'build/family-validation.json').read_text())
    current=source_hashes()
    if proof['status']!='passed' or proof['project_sources']!=current:raise ValueError('Run current family tests before packaging')
    hc88=json.loads((ROOT/'build/hc88-validation.json').read_text())
    software={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'software').glob('*'))}
    if hc88.get('status')!='passed' or hc88['project_sources']!=current or hc88['software_sources']!=software or hc88['system_disk_sha256']!=hashlib.sha256((ROOT/'assets/disks/hc88/system.dsk').read_bytes()).hexdigest():raise ValueError('Run current native HC88 tests before packaging')
    capture=json.loads((ROOT/'build/hc88-capture-validation.json').read_text())
    if capture['status']!='passed':raise ValueError('Run HC88 framebuffer verification before packaging')
    extra_proofs=['expansion-unit-validation.json','tape-memory-validation.json','fdc-validation.json','expansion-validation.json','expansion-capture-validation.json']
    for name in extra_proofs:
        evidence=json.loads((ROOT/'build'/name).read_text())
        if evidence.get('status')!='passed' or evidence.get('project_sources')!=current:
            raise ValueError('Run current verification before packaging: '+name)
    expansion=json.loads((ROOT/'build/expansion-validation.json').read_text())
    expected_runs={'hc85-dos','hc90-cpm','hc91-cpm','hc128-basic','hc128-cpm','hc2000-basic','hc2000-files'}
    if set(expansion['runs'])!=expected_runs:raise ValueError('Incomplete native expansion runtime coverage')
    simulator=expansion['simulator']
    if simulator['project_sources']!=current or simulator['binary_sha256']!=hashlib.sha256((ROOT/'build/expansion-obj/Vhc_expansion_sim').read_bytes()).hexdigest():
        raise ValueError('Native expansion simulator does not match its build record')
    for name,digest in simulator['simulation_sources'].items():
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest:raise ValueError('Simulation source changed: '+name)
    if expansion['firmware_sha256']!=hashlib.sha256((ROOT/'assets/roms/family.rom').read_bytes()).hexdigest():
        raise ValueError('Expansion firmware changed after runtime verification')
    files={'_Computer/HC.rbf' :ROOT/'build/quartus-HC/output_files/HC.rbf',
           'README.md':export_readme(),'docs/family-validation.json':ROOT/'build/family-validation.json',
           'docs/fpga-validation.json':ROOT/'build/hc-fpga-validation.json','docs/hc88-validation.json':ROOT/'build/hc88-validation.json','docs/hc88-capture-validation.json':ROOT/'build/hc88-capture-validation.json'}
    files.update({'docs/'+name:ROOT/'build'/name for name in extra_proofs})
    files.update(collect());files.update(source_files())
    # Fixed-model diagnostics initialize their ROMs from hex, while the family
    # host uploads binary banks. Export both representations of every ROM.
    hex_dir=ROOT/'build/package-romhex';hex_dir.mkdir(exist_ok=True)
    for name,path in list(files.items()):
        if name.startswith('source/assets/roms/') and name.endswith('.rom'):
            target=hex_dir/(path.stem+'.hex')
            target.write_text(''.join(f'{byte:02x}\n' for byte in path.read_bytes()))
            files[name[:-4]+'.hex']=target
    for folder in ['rtl','mister','tools','sim','software']:
        for p in sorted((ROOT/folder).rglob('*')):
            if p.is_file() and '__pycache__' not in p.parts:files['source/'+p.relative_to(ROOT).as_posix()]=p
    for p in sorted(DOCS.rglob('*')):
        rel=p.relative_to(DOCS)
        if not p.is_file() or any(x in ['reference','analysis','__pycache__'] for x in rel.parts):continue
        if len(rel.parts)==1 and p.name=='PLAN.md':continue
        files['docs/'+rel.as_posix()]=p;files['source/docs/'+rel.as_posix()]=p
    for folder in ['sys', 'rtl']:
        for p in sorted((ROOT/'vendor/spectrum'/folder).rglob('*')):
            if p.is_file():files['source/vendor/spectrum/'+p.relative_to(ROOT/'vendor/spectrum').as_posix()]=p
    for name in ['ZX-Spectrum.qsf', 'README.md']:
        files['source/vendor/spectrum/'+name]=ROOT/'vendor/spectrum'/name
    for name,entry in json.loads((DOCS/'sources.lock.json').read_text()).items():
        if name.startswith('assets/tapes/') and name.endswith('.tzx'):files['source/'+name]=ROOT/name
        if name.startswith('docs/reference/hc88/') and not name.endswith('.zip'):files['source/'+name]=DOCS/name[5:]
    files['source/README.md']=export_readme()
    output=ROOT/'dist/HC.zip';output.parent.mkdir(exist_ok=True)
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
