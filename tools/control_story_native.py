"""Submit ordinary-input commands to a live isolated story QA driver."""
from pathlib import Path
import argparse,hashlib,json,os,sys,time
from qa_storage import qa_source,qa_run,qa_popen
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('run',type=Path);p.add_argument('--commands',default='[]')
p.add_argument('--full',action='store_true');p.add_argument('--wait',type=float,default=12)
p.add_argument('--interactive',action='store_true',help='Read command arrays, {"save":true} or {"checkpoint":true} on one guarded client')
p.add_argument('--train-cave-wins',type=int,default=0,help='Bounded ordinary Fiery Path training; stop on new UI, low HP or status')
p.add_argument('--checkpoint',action='store_true',help='Record unchanged native save bytes after a completed ordinary SAVE/YES input sequence')
p.add_argument('--save-via-ui',action='store_true',help='Use single ordinary inputs to SAVE, then record its guarded checkpoint')
p.add_argument('--live-pid',type=int,help=argparse.SUPPRESS)
p.add_argument('--worker',action='store_true',help=argparse.SUPPRESS);a=p.parse_args()
run=a.run.resolve();assert run.parent==ROOT/'.local/qa'and run.name.startswith('gen2recomp-qa-')
verification=json.loads((run/'verification.json').read_text());edition=verification['edition']
assert edition in ('leafgreen','ruby','sapphire')
assert run.name.startswith('gen2recomp-qa-'+edition+'-')and verification['identity'].startswith('oasc-edition-qa-'+edition+'-')
commands=json.loads(a.commands);assert isinstance(commands,list)and all(isinstance(c,dict)for c in commands)
assert 0<=a.wait<=45
assert 0<=a.train_cave_wins<=5
assert not a.train_cave_wins or(edition in('ruby','sapphire')and not commands and not a.interactive and not a.checkpoint)
assert not a.save_via_ui or(not commands and not a.interactive and not a.checkpoint and not a.train_cave_wins)
if not a.worker:
    for src in(ROOT,Path(sys.executable)):qa_source(src)
    expected=str(run/'engine/.qa-runtime.app/Contents/MacOS/love')+' '+str(run/'engine')
    processes=qa_run(['ps','-axo','pid=,command='],capture_output=True,text=True,check=True).stdout.splitlines()
    live=[int(row.strip().split(None,1)[0])for row in processes if len(row.strip().split(None,1))==2 and row.strip().split(None,1)[1]==expected]
    assert len(live)==1,'Native story process is not live; do not restart it implicitly'
    cmd=[sys.executable,__file__,str(run),'--commands',a.commands,'--wait',str(a.wait),'--worker','--live-pid',str(live[0])]
    if a.full:cmd+=['--full']
    if a.checkpoint:cmd+=['--checkpoint']
    if a.save_via_ui:cmd+=['--save-via-ui']
    if a.train_cave_wins:cmd+=['--train-cave-wins',str(a.train_cave_wins)]
    if a.interactive:
        assert not commands,'Interactive commands arrive on stdin'
        child=qa_popen(cmd+['--interactive'],cwd=ROOT,stdin=sys.stdin,stdout=sys.stdout,stderr=sys.stderr)
        raise SystemExit(child.wait())
    result=qa_run(cmd,cwd=ROOT,capture_output=True,text=True)
    print(result.stdout,end='');print(result.stderr,end='',file=sys.stderr);raise SystemExit(result.returncode)
# This is the existing live job's output, not a new cache input. Its
# exclusive inherited lease remains with the native runner/LÖVE child.
# The guarded parent verifies the exact process command. The worker only
# exchanges files with that live job and inherits the parent's leases; it
# launches no additional child and needs no second storage collection.
assert a.live_pid and a.live_pid>0, 'Missing verified native process'
os.kill(a.live_pid,0)
def validate(commands):
    assert isinstance(commands,list)and all(isinstance(c,dict)for c in commands)
    directions=('up','down','left','right')
    for c in commands:
        op=c.get('op')
        assert op in ('press','hold','wait','step','goto','advance','battle-attack','shot','verify-continue','finish'), 'Unsupported story command'
        assert 'direction' not in c, 'Use dir for an ordinary step'
        if op=='step':assert c.get('dir')in directions, 'A step needs dir: up/down/left/right'
        if op in ('press','hold'):assert c.get('button')in (*directions,'a','b','start','select','l','r'), 'Invalid button'
        if op=='hold':assert type(c.get('frames'))is int and 1<=c['frames']<=6000,'Bounded hold duration required'
        if op=='goto':assert all(type(c.get(k))is int for k in ('x','y')), 'goto needs integer x/y'
        if op=='battle-attack':assert type(c.get('slot'))is int and 1<=c['slot']<=4, 'Invalid move slot'
        if op=='shot':assert isinstance(c.get('name'),str)and c['name'], 'A capture needs a name'
        for k in ('frames','times','wait'):
            if k in c:assert type(c[k])is int and c[k]>=0, 'Invalid frame/count value'
def submit(commands,emit=True):
    validate(commands)  # Reject the entire batch before writing the live queue.
    assert json.loads((run/'verification.json').read_text())['status']=='running','Native job has ended'
    path=run/'story-commands.json';queue=json.loads(path.read_text())if path.exists()else []
    if commands:
        queue+=commands;temp=path.with_suffix('.tmp');temp.write_text(json.dumps(queue));os.replace(temp,path)
    deadline=time.monotonic()+a.wait
    while True:
        state=json.loads((run/'story-state.json').read_text())
        report=json.loads((run/'result.json').read_text())
        # The driver publishes its snapshot just before appending the matching
        # input receipt. Wait for both: otherwise the previous command's
        # outcome can be returned alongside the next command's field state.
        recorded=report['commands'][-1]['seq']if report['commands']else 0
        if state['seq']>=len(queue)and(recorded>=len(queue)or report['status']=='pass'):break
        if time.monotonic()>=deadline:break
        if 'driver error:'in (run/'native.log').read_text(errors='replace'):raise SystemExit('Driver failed; inspect native.log')
        time.sleep(.1)
    if a.checkpoint:
        assert not state['busy']and state['seq']==len(queue)
        assert state['top']['source']=='src/world/OverworldController.lua'and not state['scriptRunning']
        report=json.loads((run/'result.json').read_text());rows=report['commands'];last=rows[-1]['seq']
        from rs_story_checkpoint import check_saved_tail,is_save_yes
        confirmed=None;first=None
        for row in reversed(rows):
            top=row['before']['top']
            if ((row['input'].get('button')=='a'or row['input'].get('op')=='advance')and is_save_yes(row['before'])):
                confirmed=row['seq'];break
        assert confirmed,'No ordinary SAVE/YES command in this run'
        for row in reversed(rows[:confirmed-1]):
            if row['before']['top'].get('source')=='src/ui/Gen3StartMenu.lua':first=row['seq'];break
        assert first and rows[-1]['after']['top']['source']=='src/world/OverworldController.lua'
        check_saved_tail(rows,confirmed,last)
        profile=Path.home()/'Library/Application Support/LOVE'/verification['identity']
        guest=profile/'profiles/guest'
        saves=list(guest.glob('save_'+edition+'.lua'))+list((guest/'saves'/edition).glob('slot[0-9]*.lua'))
        assert len(saves)==1 and not saves[0].is_symlink(),'Expected one native main checkpoint in own profile'
        checkpoint={'profileIdentity':verification['identity'],'sourceRun':run.name,
            'saveRelativePath':str(saves[0].relative_to(profile)),'sha256':hashlib.sha256(saves[0].read_bytes()).hexdigest(),
            'producedThroughNormalSaveMenu':True,'saveMenuCommandRange':[first,last],
            'saveConfirmedSeq':confirmed,'snapshotAfterSaveCommand':rows[-1]['after'],'personalSave':False}
        (run/'normal-save-checkpoint.json').write_text(json.dumps(checkpoint,indent=2)+'\n')
        state['normalCheckpointSHA256']=checkpoint['sha256']
    if not a.full:
        state.pop('flags',None)
        if state.get('map'):
            state['map'].pop('signs',None)
            if a.interactive:state['map'].pop('walkable',None)
    report=json.loads((run/'result.json').read_text());state['lastOutcome']=report['commands'][-1]['outcome']if report['commands']else None
    state['queuedCommands']=len(queue)
    if emit:print(json.dumps(state,ensure_ascii=False),flush=True)
    return state
def save_from_ui():
    from story_save_operator import save_via_ui
    def record():
        original=a.checkpoint;a.checkpoint=True
        try:return submit([],emit=False)
        finally:a.checkpoint=original
    return save_via_ui(lambda commands:submit(commands,emit=False),record)

if a.save_via_ui:
    print(json.dumps(save_from_ui(),ensure_ascii=False),flush=True)
elif a.train_cave_wins:
    from story_training import train_cave
    print(json.dumps(train_cave(lambda commands:submit(commands,emit=False),a.train_cave_wins),ensure_ascii=False),flush=True)
elif a.interactive:
    print('READY_STORY_INPUT',flush=True)
    for line in sys.stdin:
        if line.strip():
            message=json.loads(line)
            if message=={'save':True}:
                print(json.dumps(save_from_ui(),ensure_ascii=False),flush=True)
            elif message=={'checkpoint':True}:
                original=a.checkpoint;a.checkpoint=True
                try:submit([])
                finally:a.checkpoint=original
            else:submit(message)
else:submit(commands)
