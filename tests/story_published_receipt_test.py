# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
from pathlib import Path
import sys,unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from story_published_receipt import published_receipt

class PublishedReceiptTests(unittest.TestCase):
    def fixture(self,seq=7):
        return {'format':1,'identity':'own-native-profile','seq':seq,'outcome':'done'}

    def read(self,ack,report=None):
        calls=[]
        def load(name):
            calls.append(name)
            if name=='story-published.json':
                if ack is None:raise FileNotFoundError(name)
                return ack
            assert report is not None,'The growing full ledger must not be read on the fast path'
            return report
        return load,calls

    def test_published_input_does_not_parse_the_full_trace(self):
        read,calls=self.read(self.fixture())
        receipt=published_receipt(read,{'seq':7},[{'op':'press'}]*7,'own-native-profile')
        self.assertEqual(receipt,{'seq':7,'outcome':'done','passed':False})
        self.assertEqual(calls,['story-published.json'])

    def test_new_snapshot_cannot_acknowledge_an_unpublished_ledger_row(self):
        read,calls=self.read(self.fixture(6))
        receipt=published_receipt(read,{'seq':7},[{'op':'press'}]*7,'own-native-profile')
        self.assertEqual(receipt['seq'],6)
        self.assertEqual(calls,['story-published.json'])

    def test_legacy_drivers_keep_their_existing_full_report_proof(self):
        read,_=self.read(None,{'status':'running','commands':[{'seq':7,'outcome':'blocked'}]})
        receipt=published_receipt(read,{'seq':7},[{'op':'press'}]*7,'own-native-profile')
        self.assertEqual(receipt,{'seq':7,'outcome':'blocked','passed':False})

    def test_foreign_future_and_malformed_acknowledgments_fall_back(self):
        for key,value in(('identity','foreign'),('format',2),('format',True),('seq',8),('seq',True),('seq',-1),('outcome',None)):
            ack=dict(self.fixture(),**{key:value});read,calls=self.read(ack,{'status':'running','commands':[]})
            self.assertEqual(published_receipt(read,{'seq':7},[{'op':'press'}]*7,'own-native-profile')['seq'],0)
            self.assertEqual(calls,['story-published.json','result.json'])

    def test_terminal_commands_require_the_completed_full_report(self):
        for op in('finish','verify-continue'):
            for status in('running','pass'):
                read,calls=self.read(self.fixture(),{'status':status,'commands':[{'seq':6,'outcome':'done'}]})
                receipt=published_receipt(read,{'seq':7},[{'op':'press'}]*6+[{'op':op}],'own-native-profile')
                self.assertEqual(receipt['passed'],status=='pass');self.assertEqual(calls,['result.json'])

    def test_normal_input_cannot_borrow_a_passing_terminal_report(self):
        read,_=self.read(None,{'status':'pass','commands':[]})
        self.assertFalse(published_receipt(read,{'seq':1},[{'op':'press'}],'own-native-profile')['passed'])

if __name__=='__main__':unittest.main()
