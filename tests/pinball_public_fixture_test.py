"""Public native tests must reject placeholder/unsafe credentials before networking."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('public_pinball',ROOT/'tools/qualify_pinball_public.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class FixtureTest(unittest.TestCase):
    def setUp(self):
        self.fixture={'qa_only':True,'marker':'a'*32,'url':'https://pokexpert.de/api/cloud/v1/play/',
            'accounts':[{'account':'101','token':'a'*40},{'account':'102','token':'b'*40}]}
    def read(self,data):
        with tempfile.TemporaryDirectory()as tmp:
            path=Path(tmp)/'fixture.json';path.write_text(json.dumps(data));return module.read_fixture(path)
    def test_valid_disposable_pair(self):
        self.assertEqual(self.read(self.fixture),self.fixture)
    def test_public_example_never_starts_a_live_test(self):
        with self.assertRaisesRegex(ValueError,'placeholders'):module.read_fixture(ROOT/'operations/modcompass/pinball-gbc/accounts.example.json')
    def test_wrong_origin_duplicate_accounts_and_header_injection(self):
        for change in('url','duplicate','injection','real_profile','placeholder','numeric_id'):
            f=copy.deepcopy(self.fixture)
            if change=='url':f['url']='https://example.invalid/collect/'
            if change=='duplicate':f['accounts'][1]['account']='101'
            if change=='injection':f['accounts'][1]['token']='a'*40+'\nX-Leak: yes'
            if change=='real_profile':f['qa_only']=False
            if change=='numeric_id':f['accounts'][1]['account']=102
            if change=='placeholder':f['accounts'][1]['token']='REPLACE_WITH_PRIVATE_TOKEN'
            with self.subTest(change=change),self.assertRaises(ValueError):self.read(f)
if __name__=='__main__':unittest.main()
