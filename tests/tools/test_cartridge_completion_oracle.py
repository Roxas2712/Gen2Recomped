"""Keep original cartridge corrections narrow and all remaining fields strict."""
from copy import deepcopy
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/enemy-action-contract-check'))
from cartridge_completion import expected_completion
from check import same_observations
import check as CHECK


def spit():
    return dict(case='wonder-guard',count=1,amount=45,stockpile=0,pp=9,
        hits=[dict(move='SPIT_UP',typeMult=10,amount=45,substitute=False,crit=False)],
        moves=[dict(move='SPIT_UP',user='P0',target='P1')],draws=[[1,100,100]])


class CompletionOracle(unittest.TestCase):
    def test_faint_clears_only_the_dead_callers_major_status(self):
        for version in ('firered','emerald'):
            row=dict(case='user_faint',state=[dict(hp=0,status='SLP',pp=[9,10]),dict(hp=391,status='PSN')],
                draws=[[0,3,3]],events=[dict(called=True,move='DOUBLE_SLAP')])
            before=deepcopy(row)
            expected,changes=expected_completion([row],version,'post_hit_items_execution')
            wanted=deepcopy(row);del wanted['state'][0]['status']
            self.assertEqual(expected,[wanted]);self.assertEqual(row,before)
            self.assertEqual(len(changes),1)
            for mutation in ('pp','draw','live-status'):
                bad=deepcopy(wanted)
                if mutation=='pp':bad['state'][0]['pp'][0]=8
                elif mutation=='draw':bad['draws'][0][2]=2
                else:bad['state'][1]['status']='BRN'
                self.assertFalse(same_observations(expected,[bad]))

    def test_wonder_guard_keeps_pp_stockpile_events_and_draws(self):
        for version in ('firered','emerald'):
            for count in (1,2,3):
                row=spit();row['count']=count;row['amount']*=count;row['hits'][0]['amount']*=count
                expected,changes=expected_completion([row],version,'spit_up')
                wanted=deepcopy(row);wanted['amount']=0;wanted['hits']=[]
                self.assertEqual(expected,[wanted]);self.assertEqual(len(changes),1)
                for field in ('pp','stockpile','moves','draws'):
                    bad=deepcopy(wanted);bad[field]=[] if isinstance(bad[field],list)else 5
                    self.assertFalse(same_observations(expected,[bad]))

    def test_unrelated_rows_and_empty_stockpile_stay_unchanged(self):
        for mode in ('post_hit_items_execution','spit_up'):
            row=dict(case='normal',state=[dict(hp=0,status='SLP')],amount=45)
            self.assertEqual(expected_completion([row],'emerald',mode),([row],[]))
        row=spit();row['count']=0
        self.assertEqual(expected_completion([row],'emerald','spit_up'),([row],[]))

    def test_unknown_corrected_shapes_are_rejected(self):
        for field,value in (('hits',[]),('hits',[False]),('amount',False),('count',True),('stockpile',1)):
            row=spit();row[field]=value
            with self.assertRaises(ValueError):expected_completion([row],'emerald','spit_up')
        with self.assertRaises(ValueError):expected_completion([dict(case='user_faint')],'emerald','post_hit_items_execution')
        with self.assertRaises(ValueError):expected_completion([],'ruby','spit_up')
        with self.assertRaises(ValueError):expected_completion([],'emerald','arguments')

    def test_actual_cli_retains_raw_differences_and_rejects_extra_drift(self):
        old=spit();wanted=deepcopy(old);wanted['amount']=0;wanted['hits']=[]
        root=Path(CHECK.__file__).resolve().parents[2]
        for drift in (False,True):
            host=deepcopy(wanted)
            if drift:host['pp']=8
            with tempfile.TemporaryDirectory() as directory:
                source=Path(directory)/'reference';source.mkdir();report=Path(directory)/'report.json'
                def git(path,*args):return CHECK.GEN1_REF if args==('rev-parse','HEAD')else''
                def worker(command,**kwargs):
                    data=[old]if command[3]=='gen1'else[host]
                    return subprocess.CompletedProcess(command,0,'ENEMY_ACTION_OBSERVATIONS '+json.dumps(data)+'\n','')
                argv=[CHECK.__file__,'--gen1',str(source),'--gen2',str(root),'--mode','spit_up','--report',str(report)]
                with patch.object(CHECK,'git',side_effect=git),patch.object(CHECK.subprocess,'run',side_effect=worker),\
                    patch.object(sys,'argv',argv),redirect_stdout(io.StringIO()):code=CHECK.main()
                self.assertEqual(code,1 if drift else 0)
                for comparison in json.loads(report.read_text())['comparisons']:
                    self.assertFalse(comparison['equal']);self.assertEqual(comparison['accepted'],not drift)
                    self.assertEqual(comparison['oracle'],'cartridge-completion-v1')
                    self.assertEqual(comparison['observations']['gen1'],[old])
                    self.assertEqual(len(comparison['corrected_rows']),1)
