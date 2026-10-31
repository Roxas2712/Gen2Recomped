"""Fetch byte-reviewed, game-data-free upstream sources for native SDK builds."""
import hashlib,json
from pathlib import Path

def digest(path):
    with Path(path).open('rb')as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def xy_sources(root,work,qa):
    pins=json.loads((root/'tools/pokemon_xy_source_pins.json').read_text())['sources']
    for name,pin in pins.items():
        folder=work/name
        if not folder.exists():
            qa.qa_run(['git','-c','core.eol=lf','-c','core.autocrlf=false','clone','--filter=blob:none','--no-checkout','https://github.com/fearkov/'+name+'.git',str(folder)],check=True)
            qa.qa_run(['git','checkout','--detach',pin['revision']],cwd=folder,check=True)
        actual=qa.qa_run(['git','rev-parse','HEAD'],cwd=folder,capture_output=True,text=True,check=True).stdout.strip()
        if actual!=pin['revision']:raise ValueError('Unexpected source revision: '+name)
        changed=qa.qa_run(['git','status','--porcelain'],cwd=folder,capture_output=True,text=True,check=True).stdout
        if not changed:
            for patch,expected in pin['patches'].items():
                file=root/'tools/patches'/patch
                if digest(file)!=expected:raise ValueError('Patch digest mismatch: '+patch)
                qa.qa_run(['git','apply','--check',str(file)],cwd=folder,check=True)
                qa.qa_run(['git','apply',str(file)],cwd=folder,check=True)
        changed=qa.qa_run(['git','status','--porcelain'],cwd=folder,capture_output=True,text=True,check=True).stdout.splitlines()
        if any(row[3:] not in pin['patched_files'] for row in changed):raise ValueError('Preserve unreviewed changes in '+name)
        for path,expected in pin['patched_files'].items():
            if digest(folder/path)!=expected:raise ValueError('Patched source digest mismatch: '+name+'/'+path)
    return pins
