"""Install only the verified JUNIORXT package over SSH, with backup and readback."""
from project_paths import ROOT
from pathlib import Path,PurePosixPath
from datetime import datetime,timezone
import argparse,base64,hashlib,io,json,os,posixpath,stat,zipfile
import paramiko

def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--host',required=True);p.add_argument('--host-key',required=True);args=p.parse_args()
 package=ROOT/'dist/JUNIORXT.zip';proof=json.loads((ROOT/'build/package-validation.json').read_text());blob=package.read_bytes()
 if proof['status']!='passed' or sha(blob)!=proof['zip_sha256']:raise ValueError('Run current package verification before deployment')
 with zipfile.ZipFile(io.BytesIO(blob)) as z:
  sums={n:h for h,n in (s.split('  ',1) for s in z.read('SHA256SUMS').decode().splitlines())}
  files={n:z.read(n) for n in sums if n.startswith(('_Computer/','games/'))}
  for n,b in files.items():
   parts=PurePosixPath(n).parts
   if '..' in parts or not (n in ['_Computer/JUNIORXT.mgl','_Computer/.JUNIORXT/JUNIORXT.rbf'] or n.startswith('games/JUNIORXT/')) or sha(b)!=sums[n]:raise ValueError('Unsafe or corrupt installation member')
 class Pinned(paramiko.MissingHostKeyPolicy):
  def missing_host_key(self,client,hostname,key):
   actual='SHA256:'+base64.b64encode(hashlib.sha256(key.asbytes()).digest()).decode().rstrip('=')
   if actual!=args.host_key:raise ValueError('Unexpected SSH host key')
 ssh=paramiko.SSHClient();ssh.set_missing_host_key_policy(Pinned())
 ssh.connect(args.host,username='root',password=os.environ['MISTER_PASSWORD'],allow_agent=False,look_for_keys=False,timeout=15)
 sftp=ssh.open_sftp();base='/media/fat';stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ');stage=base+'/.juniorxt-deploy-'+stamp
 workspace=ROOT.parent.parent if (ROOT.parent.parent/'docs/juniorxt').is_dir() else ROOT
 local=workspace/'build/deployments'/stamp;local.mkdir(parents=True)
 def info(path):
  try:return sftp.lstat(path)
  except FileNotFoundError:return None
 def read(path):
  with sftp.open(path,'rb') as f:return f.read()
 def mkdirs(path):
  if path==base:return
  found=info(path)
  if found:
   if not stat.S_ISDIR(found.st_mode):raise ValueError('Not a directory: '+path)
   return
  mkdirs(posixpath.dirname(path));sftp.mkdir(path)
 def cleanup(path):
  if path!=stage and not path.startswith(stage+'/'):raise ValueError('Unsafe staging cleanup')
  for item in sftp.listdir_attr(path):
   child=path+'/'+item.filename
   if stat.S_ISDIR(item.st_mode):cleanup(child)
   else:sftp.remove(child)
  sftp.rmdir(path)
 preserve={n:sha(read(base+'/'+n)) for n in ['_Computer/HC.rbf','_Computer/CIP.rbf','_Computer/CUBZ.rbf'] if info(base+'/'+n)}
 receipt={'status':'preparing','host':args.host,'host_key':args.host_key,'package_sha256':sha(blob),'files':{},'preserved_cores':preserve,'backup':str(local/'previous')}
 def save(): (local/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 save();old={};changed=[]
 try:
  for n in files:
   dest=base+'/'+n;found=info(dest)
   if found:
    if not stat.S_ISREG(found.st_mode):raise ValueError('Not a regular file: '+dest)
    old[n]=read(dest);target=local/'previous'/n;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(old[n])
    if sha(target.read_bytes())!=sha(old[n]):raise ValueError('Backup failed')
  mkdirs(stage)
  for n,b in files.items():
   target=stage+'/new/'+n;mkdirs(posixpath.dirname(target))
   with sftp.open(target,'wb') as f:f.set_pipelined(True);f.write(b)
   if sha(read(target))!=sha(b):raise ValueError('Staged checksum mismatch: '+n)
   receipt['files'][n]={'sha256':sha(b),'bytes':len(b)}
  receipt['status']='staged and verified';save()
  for n in files:
   current=info(base+'/'+n)
   if n in old:
    if not current or sha(read(base+'/'+n))!=sha(old[n]):raise ValueError('Destination changed during upload')
   elif current:raise ValueError('Destination appeared during upload')
  for n in sorted(files,key=lambda n:(n.startswith('_Computer/'),n)):
   target=base+'/'+n;mkdirs(posixpath.dirname(target))
   if n in old:
    backup=stage+'/old/'+n;mkdirs(posixpath.dirname(backup));sftp.rename(target,backup)
   changed.append(n);sftp.rename(stage+'/new/'+n,target)
  _,out,err=ssh.exec_command('sync');out.read()
  if out.channel.recv_exit_status()!=0:raise ValueError('Remote sync failed: '+err.read().decode())
  for n,b in files.items():
   if sha(read(base+'/'+n))!=sha(b):raise ValueError('Installed checksum mismatch: '+n)
  for n,h in preserve.items():
   if sha(read(base+'/'+n))!=h:raise ValueError('Another core changed during deployment')
  receipt['status']='installed and SHA-256 verified';receipt['finished_utc']=datetime.now(timezone.utc).isoformat();save()
  print('PASS:',len(files),'JUNIORXT files installed and verified;',len(preserve),'existing family cores preserved');print(local/'receipt.json')
 except BaseException:
  for n in reversed(changed):
   target=base+'/'+n
   if info(target):sftp.remove(target)
   if n in old:sftp.rename(stage+'/old/'+n,target)
  receipt['status']='failed; published files rolled back';save()
  if info(stage):cleanup(stage)
  raise
 else:
  cleanup(stage)
 finally:sftp.close();ssh.close()
if __name__=='__main__':main()
