import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('mist_compare', Path(__file__).resolve().parents[1] / 'tools/gen3_mist_compare.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class MistComparisonTest(unittest.TestCase):
    def pair(self, **changes):
        reference = dict(label='guaranteed secondary protected', speed=-1, timer=5, attack=0)
        native = dict(reference, speed=0, **changes)
        return reference, native

    def test_known_reference_difference_is_visible(self):
        a, b = self.pair()
        result = module.compare_rows([a], [b], 'mist')
        self.assertFalse(result['equal'])
        self.assertTrue(result['matching_expected'])
        self.assertEqual(len(result['known_reference_differences']), 1)
        self.assertEqual(result['unclassified_differences'], [])

    def test_timer_or_other_effect_changes_are_rejected(self):
        a, b = self.pair(timer=4)
        self.assertFalse(module.compare_rows([a], [b], 'mist')['matching_expected'])
        a, b = self.pair()
        self.assertFalse(module.compare_rows([a], [b], 'haze')['matching_expected'])
        self.assertFalse(module.compare_rows([b], [a], 'mist')['matching_expected'])

    def test_missing_rows_and_changed_labels_are_rejected(self):
        a, b = self.pair()
        self.assertFalse(module.compare_rows([a], [], 'mist')['matching_expected'])
        self.assertFalse(module.compare_rows(None, None, 'mist')['matching_expected'])
        self.assertFalse(module.compare_rows(None, None, 'mist')['equal'])
        b['label'] = 'other side unprotected'
        self.assertFalse(module.compare_rows([a], [b], 'mist')['matching_expected'])

    def test_equal_records_need_no_exception(self):
        a, _ = self.pair()
        result = module.compare_rows([a], [dict(a)], 'mist')
        self.assertTrue(result['equal'])
        self.assertTrue(result['matching_expected'])
        self.assertEqual(result['known_reference_differences'], [])


if __name__ == '__main__':
    unittest.main()
