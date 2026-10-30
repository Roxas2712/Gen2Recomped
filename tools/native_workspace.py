"""Native import process limits; Windows never deletes player/source data.

POSIX development uses the existing QA controller. Windows keeps build budgets
and the 20-GiB reserve, terminating only its own child tree on a violation.
Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""
import atexit, os, shutil, subprocess, threading, time
from pathlib import Path

GIB=1024**3
def lock_file(file):
    if os.name=='nt':
        import msvcrt
        file.seek(0,2)
        if file.tell()==0:file.write('\0');file.flush()
        file.seek(0)
        try:msvcrt.locking(file.fileno(),msvcrt.LK_NBLCK,1)
        except OSError as exc:raise BlockingIOError('This native workspace is already in use') from exc
    else:
        import fcntl
        fcntl.flock(file,fcntl.LOCK_EX|fcntl.LOCK_NB)

class WindowsStorage:
    def __init__(self,root):self.root=Path(root).resolve();self.limits={}
    def limit_output(self,path,limit):self.limits[Path(path).resolve()]=limit
    def check_space(self):
        if shutil.disk_usage(self.root).free<20*GIB:raise RuntimeError('Keep at least 20 GiB free for native game preparation. Existing games and saves were preserved.')
    def check(self):
        self.check_space()
        for path,limit in self.limits.items():
            total=0
            if path.is_file():total=path.stat().st_size
            elif path.is_dir():
                for folder,dirs,files in os.walk(path,followlinks=False):
                    dirs[:]=[d for d in dirs if not(Path(folder)/d).is_symlink()]
                    for name in files:
                        item=Path(folder)/name
                        try:
                            if not item.is_symlink():total+=item.stat().st_size
                        except FileNotFoundError:pass  # A compiler committed/retired its temporary output.
                    if total>limit:break
            if total>limit:raise RuntimeError('Native build storage limit exceeded. Sources, ROMs and saves were preserved: '+str(path))
    def close(self,**_):pass

class WindowsManager:
    def __init__(self,root):self._storage=WindowsStorage(root)
    def qa_source(self,path):return path
    def qa_cache(self,path):self._storage.limit_output(path,4*GIB);return path
    def qa_copy(self,path,**_):return self.qa_cache(path)
    def qa_profile(self,path):return path
    def qa_limit_output(self,path,limit):self._storage.limit_output(path,limit)
    def qa_run(self,argv,**kwargs):
        self._storage.check();check=kwargs.pop('check',False);timeout=kwargs.pop('timeout',None)
        capture=kwargs.pop('capture_output',False)
        if capture:kwargs.update(stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        process=subprocess.Popen(argv,**kwargs);stop=threading.Event();problems=[]
        def monitor():
            while not stop.wait(1):
                try:self._storage.check()
                except (OSError,RuntimeError) as exc:
                    problems.append(exc)
                    subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                    return
        watcher=threading.Thread(target=monitor,daemon=True);watcher.start()
        try:
            try:stdout,stderr=process.communicate(timeout=timeout)
            except subprocess.TimeoutExpired:
                subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                process.communicate();raise
        finally:stop.set();watcher.join()
        if problems:raise problems[0]
        self._storage.check()
        result=subprocess.CompletedProcess(argv,process.returncode,stdout,stderr)
        if check:result.check_returncode()
        return result

def manager(root,collect=False):
    if os.name=='nt':return WindowsManager(root)
    import qa_storage as qa
    qa._storage=qa.Storage(root);atexit.register(qa._storage.close,collect=collect)
    return qa
