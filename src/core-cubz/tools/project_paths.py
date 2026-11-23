"""Locate component files in the consolidated tree or a standalone source export."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
DOCS=ROOT/'docs'
if not (DOCS/'dependencies.lock.json').is_file():
    DOCS=ROOT.parent.parent/'docs'/'cubz'
README=ROOT/'README.md' if (ROOT/'README.md').is_file() else DOCS/'README.md'
PLAN=ROOT/'PLAN.md' if (ROOT/'PLAN.md').is_file() else DOCS/'PLAN.md'
def source_path(name):
    return DOCS/name[5:] if name.startswith('docs/') else ROOT/name
def export_readme():
    if README.parent!=DOCS:return README
    text=README.read_text()
    def link(match):
        target=match.group(1)
        if ':' not in target and not target.startswith(('#','/')):
            target='docs/'+target
        return ']('+target+')'
    text=re.sub(r'\]\(([^)]+)\)',link,text)
    out=ROOT/'build/package-README.md';out.parent.mkdir(exist_ok=True);out.write_text(text)
    return out
