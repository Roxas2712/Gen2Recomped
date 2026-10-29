import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('analyzer', Path(__file__).resolve().parents[1] / 'tools/analyze_runtime_bottleneck.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AnalysisTest(unittest.TestCase):
    def test_nested_capture_and_unfocused_evidence(self):
        frames = [{'ms': n, 'focused': n != 30, 'drawMs': n / 2} for n in (10, 20, 30)]
        sample = dict(samples=4, states={'C': 3, 'N': 1}, frames=frames,
                      self=[dict(name='native', hits=3)], inclusive=[], stacks=[])
        capture = dict(sampling=sample, restored=True, legs=[
            dict(name='control-A', frames=frames[:1]), dict(name='control-B', frames=frames[1:])])
        r = module.analyze({'consumer': {'bottleneck': capture}})
        self.assertEqual(r['self'][0]['samplePercent'], 75)
        self.assertEqual(r['pairedCases']['control']['meanMs'], 20)
        self.assertEqual(r['pairedCases']['control']['focused'], 2)
        self.assertEqual(r['sampling']['p95Ms'], 30)
        self.assertFalse(r['gpuTimeMeasured'])
        self.assertFalse(r['qualifiedFps'])

    def test_no_samples_and_invalid_frames(self):
        r = module.analyze(dict(samples=0, states={}, frames=[{'ms': float('nan')}], self=[], inclusive=[], stacks=[]))
        self.assertEqual(r['sampling'], {'frames': 0})
        self.assertEqual(r['self'], [])
        with self.assertRaisesRegex(ValueError, 'No runtime'):
            module.analyze({'unrelated': []})


if __name__ == '__main__':
    unittest.main()
