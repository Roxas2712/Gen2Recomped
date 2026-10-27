"""Traffic totals distinguish live clients from fixture-only worker polling."""
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from qa_http_traffic import TrafficMeter


class TrafficTotals(unittest.TestCase):
    def test_counts_both_directions_and_excludes_worker_from_client_groups(self):
        meter = TrafficMeter()
        meter.record('/api/cloud/v1/tournaments/private-id/matches/private-id/battle-wire', 10, 40, 200)
        meter.record('/api/cloud/v1/play/presence', 20, 30, 200)
        meter.record('/api/cloud/v1/verifier/jobs/claim', 2, 900, 200)
        result = meter.snapshot()
        self.assertEqual(result['battle_wire']['request_body_bytes'], 10)
        self.assertEqual(result['battle_wire']['response_body_bytes'], 40)
        self.assertEqual(result['presence']['requests'], 1)
        self.assertEqual(result['verifier']['response_body_bytes'], 900)

    def test_never_retains_account_paths_query_values_or_message_data(self):
        meter = TrafficMeter()
        meter.record('/api/cloud/v1/private-account-name?secret=never-store', 9, 11, 429)
        result = meter.snapshot()
        self.assertEqual(result['other_client_api']['failures'], 1)
        self.assertEqual(result['other_client_api']['status_codes'], {'429': 1})
        self.assertNotIn('private-account-name', json.dumps(result))
        self.assertNotIn('secret', json.dumps(result))
        result['other_client_api']['requests'] = 100
        self.assertEqual(meter.snapshot()['other_client_api']['requests'], 1)


if __name__ == '__main__':
    unittest.main()
