"""Install a verified Romanian core package over pinned SSH, with backup and readback."""
from pathlib import Path,PurePosixPath
from datetime import datetime,timezone
import argparse,base64,hashlib,io,json,os,posixpath,stat,zipfile
import paramiko

def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--host',required=True);p.add_argument('--host-key',required=True);a=p.parse_args();root=a.root.resolve();name=json.loads((root/'mister/profile.json').read_text())['name']
 if name not in ['AMIC','PRAE','JET','TIMS','COBRA']:raise ValueError('Unrecognized project')
 package=root/'dist'/(name+'.zip');blob=package.read_bytes();proof=json.loads((root/'build/package-validation.json').read_text())
 if proof['status']!='passed' or proof['zip_sha256']!=sha(blob):raise ValueError('Run current package verification before installation')
 with zipfile.ZipFile(io.BytesIO(blob)) as z:
  sums={n:h for h,n in (line.split('  ',1) for line in z.read('SHA256SUMS').decode().splitlines())};files={n:z.read(n) for n in sums if n.startswith(('_Computer/','games/'))}
  for n,data in files.items():
   if '..' in PurePosixPath(n).parts or not (n=='_Computer/'+name+'.rbf' or n.startswith('games/'+name+'/')) or sha(data)!=sums[n]:raise ValueError('Unsafe installation member: '+n)
 class Pinned(paramiko.MissingHostKeyPolicy):
  def missing_host_key(self,client,hostname,key):
   actual='SHA256:'+base64.b64encode(hashlib.sha256(key.asbytes()).digest()).decode().rstrip('=')
   if actual!=a.host_key:raise ValueError('Unexpected SSH host key')
 ssh=paramiko.SSHClient();ssh.set_missing_host_key_policy(Pinned());ssh.connect(a.host,username='root',password=os.environ['MISTER_PASSWORD'],allow_agent=False,look_for_keys=False,timeout=15);sftp=ssh.open_sftp();base='/media/fat';stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ');stage=base+'/.install-'+name.lower()+'-'+stamp;local=root/'build/deployments'/stamp;local.mkdir(parents=True)
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
 cores=['_Computer/'+n+'.rbf' for n in ['HC','CIP','CUBZ','JUNIORXT','AMIC','PRAE','JET','TIMS','COBRA'] if n!=name and info(base+'/_Computer/'+n+'.rbf')]
 if info(base+'/_Computer/.JUNIORXT/JUNIORXT.rbf'):cores.append('_Computer/.JUNIORXT/JUNIORXT.rbf')
 preserved={n:sha(read(base+'/'+n)) for n in cores}
 def active():
  _,out,_=ssh.exec_command('cat /tmp/CORENAME');return out.read().decode(errors='replace').strip()
 receipt={'status':'preparing','core':name,'host':a.host,'host_key':a.host_key,'package_sha256':sha(blob),'active_core_before':active(),'preserved_cores':preserved,'preserved_user_media':{},'files':{},'backup':str(local/'previous')}
 def save():(local/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 save();previous={};changed=[]
 try:
  for n,data in list(files.items()):
   destination=base+'/'+n;found=info(destination)
   if found:
    if not stat.S_ISREG(found.st_mode):raise ValueError('Not a regular file: '+destination)
    old=read(destination)
    # A writable disk or print job may contain the user's work. Preserve it.
    if n.endswith(('.dsk','.prn')) and old!=data:receipt['preserved_user_media'][n]=sha(old);del files[n];continue
    previous[n]=old;backup=local/'previous'/Path(*PurePosixPath(n).parts);backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(old)
   staged=stage+'/'+n;mkdirs(posixpath.dirname(staged))
   with sftp.open(staged,'wb') as f:f.write(data)
   if sha(read(staged))!=sha(data):raise ValueError('Staging readback mismatch: '+n)
  for n,data in sorted(files.items(),key=lambda pair:pair[0].endswith('.rbf')):
   destination=base+'/'+n;mkdirs(posixpath.dirname(destination))
   if info(destination):sftp.remove(destination)
   changed.append(n);sftp.rename(stage+'/'+n,destination)
   if sha(read(destination))!=sha(data):raise ValueError('Installed readback mismatch: '+n)
   receipt['files'][n]={'bytes':len(data),'sha256':sha(data)}
  if {n:sha(read(base+'/'+n)) for n in preserved}!=preserved:raise ValueError('An unrelated core changed')
  receipt['active_core_after']=active()
  if receipt['active_core_after']!=receipt['active_core_before']:raise ValueError('Active session changed during installation')
  ssh.exec_command('sync')[1].channel.recv_exit_status();receipt['status']='installed';save();cleanup(stage);print('PASS installed and read back',name,len(files),'files; active core',receipt['active_core_after'])
 except Exception as error:
  receipt['status']='failed';receipt['error']=str(error);receipt['rollback_errors']=[]
  for n in reversed(changed):
   try:
    destination=base+'/'+n
    if info(destination):sftp.remove(destination)
    if n in previous:
     with sftp.open(destination,'wb') as f:f.write(previous[n])
     if sha(read(destination))!=sha(previous[n]):raise ValueError('Rollback readback mismatch')
   except Exception as rollback:receipt['rollback_errors'].append(n+': '+str(rollback))
  save();raise
 finally:sftp.close();ssh.close()
if __name__=='__main__':main()
