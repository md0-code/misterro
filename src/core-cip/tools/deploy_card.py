"""Install validated CIP-family files on a mounted MiSTer card with hash verification."""
from pathlib import Path
import argparse,hashlib,json,os,shutil
from validate_quartus import validate,source_hashes
from bundles import collect
ROOT=Path(__file__).resolve().parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def validated_files():
    from prepare_family import hashes
    validate('CIP')
    report=json.loads((ROOT/'build/family-validation.json').read_text())
    if report['status']!='passed' or report['project_sources']!=hashes():raise ValueError('Stale family checks')
    files={'_Computer/CIP.rbf':ROOT/'build/quartus-CIP/output_files/CIP.rbf'}
    files.update(collect())
    return dict(sorted(files.items(),key=lambda item:(item[0].startswith('_Computer/'),item[0])))
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('card',type=Path);args=p.parse_args()
    card=args.card.resolve()
    if not (card/'_Computer').is_dir() or not (card/'MiSTer').is_file():raise ValueError('Not a mounted MiSTer card')
    files=validated_files()
    obsolete=[card/'_Computer'/name for name in ['CIP01.rbf','CIP02.rbf','CIP03.rbf','CIP04_experimental.rbf'] if (card/'_Computer'/name).is_file()]
    for target in obsolete:target.resolve().relative_to(card)
    staged=[];replaced=[];backups={};manifest={}
    try:
        for name,source in files.items():
            target=card/name;target.parent.mkdir(parents=True,exist_ok=True)
            target.resolve().relative_to(card)
            stage=target.with_name(target.name+'.cip-stage')
            if stage.exists():raise ValueError(f'Staging file already exists: {stage}')
            shutil.copyfile(source,stage);staged.append(stage)
            expected=digest(source)
            if digest(stage)!=expected:raise ValueError(f'Copy checksum mismatch: {name}')
            manifest[name]={'sha256':expected,'bytes':source.stat().st_size}
        for name in files:
            target=card/name;stage=target.with_name(target.name+'.cip-stage')
            if target.exists():
                backup=target.with_name(target.name+'.cip-backup')
                if backup.exists():raise ValueError(f'Backup already exists: {backup}')
                os.replace(target,backup);backups[target]=backup
            os.replace(stage,target);replaced.append(target)
        for target in obsolete:
            backup=target.with_name(target.name+'.cip-backup')
            if backup.exists():raise ValueError(f'Backup already exists: {backup}')
            os.replace(target,backup);backups[target]=backup
        for name in files:
            if digest(card/name)!=manifest[name]['sha256']:raise ValueError(f'Installed checksum mismatch: {name}')
    except Exception:
        for target in reversed(replaced):target.unlink(missing_ok=True)
        for target,backup in backups.items():os.replace(backup,target)
        raise
    finally:
        for stage in staged:stage.unlink(missing_ok=True)
    for backup in backups.values():backup.unlink()
    receipt={'card':str(card),'files':manifest,'removed':[str(p.relative_to(card)) for p in obsolete],'status':'installed and checksum verified','hardware_test':'pending',
        'qualification':'CIP02 ROM selection is a firmware profile; CIP04 is experimental and exposes the verified 128K +3 map, not full 256K hardware.'}
    (ROOT/'build/deployment.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))
if __name__=='__main__':main()
