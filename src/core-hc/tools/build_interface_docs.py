"""Bundle the original Interface 1 documents without renaming their scope."""
from project_paths import DOCS
import zipfile

def main():
 for family,names in [('hc85-if1',['manual.pdf','technical.pdf','annex.pdf','schematic.pdf']),('hc90-if1',['schematic.pdf'])]:
  folder=DOCS/'reference/expansions'/family
  with zipfile.ZipFile(folder/'support.zip','w',zipfile.ZIP_DEFLATED) as z:
   for name in names:
    zi=zipfile.ZipInfo(name,date_time=(1980,1,1,0,0,0));zi.compress_type=zipfile.ZIP_DEFLATED;z.writestr(zi,(folder/name).read_bytes())
if __name__=='__main__':main()
