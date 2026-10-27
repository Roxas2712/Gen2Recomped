"""Private X/Y library, presentation preferences and reversible mod folders.

Integration by Roxas2712. ROMs, saves and mods remain local inputs.
"""
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import tomllib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.local/pokemon-x'
EDITIONS = {'x': '0004000000055D00', 'y': '0004000000055E00'}
DEFAULTS = dict(resolution=3, layout='stacked', filter='smooth', stereo='off',
                depth_3d=50, swap_eyes=False, texture_packs=True,
                frame_interpolation=False, show_fps=False, language='german',
                display_mode='fit', overlay_position='right', overlay_size=32, overlay_x=98, overlay_y=98, hide_empty_touch=True)
CHOICES = dict(resolution=range(1,9), layout=['stacked','side_by_side','large_top','top_only','bottom_only','overlay'],
               filter=['smooth','sharp','pixels'], stereo=['off','anaglyph','side_by_side','half_side_by_side','interlaced'],
               depth_3d=range(101), display_mode=['fit','crop','stretch'], overlay_position=['right','left','free'],
               overlay_size=range(15,61), overlay_x=range(101), overlay_y=range(101), language=['english','german','french','italian','spanish','japanese','korean'])
MOD_ROOTS = {'romfs', 'romfs_ext', 'textures', 'exefs', 'code.bin', 'code.ips', 'code.bps', 'exheader.bin'}


def manifest():
    path = WORK / 'library.json'
    return json.loads(path.read_text()) if path.is_file() else {}


def setting_path(edition):
    return WORK / 'settings' / edition / 'zakuro/settings.toml'


def settings(edition):
    path = setting_path(edition)
    data = tomllib.loads(path.read_text()) if path.is_file() else {}
    return {k: data.get(k, v) for k,v in DEFAULTS.items()}


def configure(edition, changes):
    for key, value in changes.items():
        if key not in DEFAULTS:
            raise ValueError('Unbekannte Einstellung: ' + key)
        if type(DEFAULTS[key]) is bool:
            if type(value) is not bool: raise ValueError('Boolean benötigt: ' + key)
        elif type(value) is not type(DEFAULTS[key]) or value not in CHOICES[key]:
            raise ValueError('Ungültiger Einstellwert: ' + key)
    path = setting_path(edition)
    text = path.read_text() if path.is_file() else ''
    # Only edit our top-level scalar keys. Keep mappings, bindings and all
    # unknown upstream settings intact, including tables following them.
    split = re.search(r'^\[', text, re.M)
    head, tail = (text[:split.start()],text[split.start():]) if split else (text,'')
    for key, value in changes.items():
        line = key + ' = ' + json.dumps(value,ensure_ascii=False)
        pattern = r'^' + re.escape(key) + r'\s*=.*$'
        if re.search(pattern,head,re.M): head = re.sub(pattern,lambda _:line,head,flags=re.M)
        else: head += ('\n' if head and not head.endswith('\n') else '') + line + '\n'
    path.parent.mkdir(parents=True,exist_ok=True)
    pending = path.with_suffix('.pending')
    pending.write_text(head+tail);pending.replace(path)


def mod_dir(edition):
    return WORK / 'player/mods' / EDITIONS[edition]


def disabled_dir(edition):
    return WORK / 'player/mods-disabled' / EDITIONS[edition]


def toggle_mods(edition):
    active, disabled = mod_dir(edition), disabled_dir(edition)
    if active.exists() and disabled.exists():
        raise ValueError('Aktiver und geparkter Mod-Ordner vorhanden; bitte zuerst manuell zusammenführen.')
    source, target = (active,disabled) if active.exists() else (disabled,active)
    if source.exists():
        target.parent.mkdir(parents=True,exist_ok=True);source.rename(target)
    else: active.mkdir(parents=True,exist_ok=True)


def _relative(name):
    # Zip names use '/', reject Windows paths and alternate traversal too.
    if '\\' in name or '\x00' in name or ':' in name: raise ValueError('Unsicherer Mod-Pfad')
    p=Path(name)
    if p.is_absolute() or '..' in p.parts: raise ValueError('Unsicherer Mod-Pfad')
    return p


def install_mod(edition, source):
    """Import supported data, fail before mutation on collisions/traversal.

    Users can deactivate the whole installed set without losing mod bytes.
    Executable patches remain subject to the backend's code-change fallback.
    """
    source=Path(source).resolve()
    target=disabled_dir(edition) if disabled_dir(edition).exists() else mod_dir(edition)
    entries=[]
    archive=None
    try:
        if source.is_dir():
            roots=list(source.iterdir())
            if len(roots)==1 and roots[0].is_dir() and roots[0].name not in MOD_ROOTS: source=roots[0]
            for path in source.rglob('*'):
                if path.is_symlink(): raise ValueError('Symlinks in Mods werden nicht importiert.')
                if path.is_file(): entries.append((path.relative_to(source),path.stat().st_size,path))
        elif zipfile.is_zipfile(source):
            archive=zipfile.ZipFile(source)
            files=[i for i in archive.infolist() if not i.is_dir()]
            paths=[_relative(i.filename) for i in files]
            prefix = paths[0].parts[0] if paths else None
            strip=prefix not in MOD_ROOTS and all(len(p.parts)>1 and p.parts[0]==prefix for p in paths)
            for info,path in zip(files,paths):
                if (info.external_attr>>16)&0o170000==0o120000: raise ValueError('Symlink im ZIP')
                entries.append((Path(*path.parts[1:]) if strip else path,info.file_size,info))
        else: raise ValueError('Mod als Ordner oder ZIP auswählen.')
        entries=[e for e in entries if e[0].parts and e[0].parts[0] in MOD_ROOTS]
        if not entries: raise ValueError('Kein romfs-/romfs_ext-/textures-/exefs-Mod gefunden.')
        seen=set();total=0
        for rel,size,_ in entries:
            _relative(str(rel));total+=size
            if rel in seen or (target/rel).exists(): raise ValueError('Mod-Datei bereits vorhanden: '+str(rel))
            for parent in (target/rel, *(target/rel).parents):
                if parent.is_symlink(): raise ValueError('Mod-Ziel enthält einen Symlink.')
                if parent == WORK: break
            seen.add(rel)
        if total>2*1024**3: raise ValueError('Mod überschreitet 2 GiB.')
        if shutil.disk_usage(WORK).free-total<20*1024**3: raise ValueError('20-GiB-Speicherreserve würde unterschritten.')
        # Stage in the same filesystem. Roll back only files created by us.
        target.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.mod-import-',dir=target.parent) as stage:
            for rel,_,item in entries:
                out=Path(stage)/rel;out.parent.mkdir(parents=True,exist_ok=True)
                if archive:
                    with archive.open(item) as inp,out.open('xb') as dest: shutil.copyfileobj(inp,dest)
                else: shutil.copyfile(item,out)
            created=[]
            try:
                for rel,_,_ in entries:
                    out=target/rel;out.parent.mkdir(parents=True,exist_ok=True)
                    # Hard link gives no-overwrite creation atomically.
                    os.link(Path(stage)/rel,out);created.append(out)
            except Exception:
                for out in created: out.unlink()
                raise
        return len(entries)
    finally:
        if archive: archive.close()


def language_preference(edition, data=None):
    path=(Path(data) if data else WORK/'player')/('language-'+edition+'.json')
    try:
        value=json.loads(path.read_text())
        if value.get('version')==1 and value.get('language') in CHOICES['language']:return value['language']
    except (OSError,ValueError,TypeError,AttributeError):pass


def reset_language(edition):
    path=WORK/'player'/('language-'+edition+'.json')
    if path.is_file():path.replace(path.with_suffix('.json.previous'))


def status():
    data=manifest()
    for edition,title in EDITIONS.items():
        row=data.setdefault(edition,{})
        library=Path(row.get('library',''))
        row['ready']=bool(row.get('built')) and library.is_file() and Path(row.get('rom','')).is_file()
        row['settings']=settings(edition)
        row['remembered_language']=language_preference(edition)
        active,disabled=mod_dir(edition),disabled_dir(edition)
        row['mods_enabled']=not disabled.exists()
        folder=disabled if disabled.exists() else active
        row['mod_files']=sum(1 for p in folder.rglob('*') if p.is_file()) if folder.exists() else 0
        row['mods_path']=str(folder)
    return data


def register(edition, rom, sha256, binary):
    import fcntl
    with (WORK/'library.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        data=manifest()
        data[edition]=dict(title_id=EDITIONS[edition],rom=str(rom),sha256=sha256,library=str(binary),built=True)
        path=WORK/'library.json';pending=path.with_suffix('.pending')
        pending.write_text(json.dumps(data,indent=2)+'\n');pending.replace(path)
