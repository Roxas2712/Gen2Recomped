import copy
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('retry',
    Path(__file__).resolve().parents[1] / 'tools/ci/native_capacity_retry.py')
retry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(retry)


class CapacityRetry(unittest.TestCase):
    def setUp(self):
        self.run = {'id': 42, 'name': retry.WORKFLOW, 'event': 'workflow_dispatch',
            'status': 'completed', 'conclusion': 'failure', 'run_attempt': 1,
            'head_repository': {'full_name': 'owner/repo'}}
        self.job = {'status': 'completed', 'conclusion': 'cancelled',
            'runner_name': '', 'steps': [], 'labels': ['macos-15']}
        self.annotations = [
            {'message': 'The job was not acquired by Runner of type hosted even after multiple attempts'},
            {'message': 'Due to capacity constraints, jobs targeting macOS arm64 runners may experience longer queue times.'},
        ]

    def test_observed_capacity_failure_is_eligible(self):
        self.assertTrue(retry.eligible_run(self.run, 'owner/repo', 42))
        self.assertTrue(retry.capacity_job(self.job, self.annotations))

    def test_human_cancel_success_active_foreign_and_old_requests_are_not_retried(self):
        for key, value in [('conclusion', 'cancelled'), ('conclusion', 'success'),
                ('status', 'in_progress'), ('event', 'pull_request'),
                ('name', 'another workflow'), ('run_attempt', 4), ('run_attempt', None),
                ('head_repository', {'full_name': 'foreign/repo'})]:
            with self.subTest(key=key, value=value):
                run = copy.deepcopy(self.run);run[key] = value
                self.assertFalse(retry.eligible_run(run, 'owner/repo', 42))
        self.assertFalse(retry.eligible_run(self.run, 'owner/repo', 43))

    def test_started_failed_running_nonmac_and_selfhosted_jobs_are_not_retried(self):
        for key, value in [('conclusion', 'failure'), ('status', 'in_progress'),
                ('runner_name', 'assigned-runner'), ('steps', [{'name': 'test', 'conclusion': 'failure'}]),
                ('labels', ['ubuntu-24.04']), ('labels', ['self-hosted', 'macos-15'])]:
            with self.subTest(key=key, value=value):
                job = copy.deepcopy(self.job);job[key] = value
                self.assertFalse(retry.capacity_job(job, self.annotations))

    def test_human_cancel_or_incomplete_annotations_are_not_capacity_proof(self):
        for annotations in [[], [{'message': 'Cancelled by the user'}],
                self.annotations[:1], self.annotations[1:]]:
            with self.subTest(annotations=annotations):
                self.assertFalse(retry.capacity_job(self.job, annotations))

    def test_check_identity_is_taken_from_the_same_repository(self):
        self.assertEqual(retry.check_run_id({'check_run_url':
            'https://api.github.com/repos/owner/repo/check-runs/101'}, 'owner/repo'), 101)
        for url in ['', 'https://other.example/check-runs/101',
                'https://api.github.com/repos/foreign/repo/check-runs/101',
                'https://api.github.com/repos/owner/repo/check-runs/101/extra']:
            self.assertIsNone(retry.check_run_id({'check_run_url': url}, 'owner/repo'))

    def test_controller_retries_one_job_and_preserves_real_failure_and_stale_run_guards(self):
        for case in ['capacity', 'test-failure', 'obsolete', 'already-retried', 'human-cancel']:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                observed = copy.deepcopy(self.run)
                run = dict(observed, workflow_id=7)
                if case == 'already-retried':run['run_attempt'] = 2
                if case == 'human-cancel':run['conclusion'] = 'cancelled'
                jobs = [dict(self.job, id=9, check_run_url=
                    'https://api.github.com/repos/owner/repo/check-runs/101')]
                if case == 'test-failure':jobs.append({'id': 10, 'conclusion': 'failure'})
                requests = []

                class Response:
                    def __init__(self, value):self.value = value
                    def __enter__(self):return self
                    def __exit__(self, *args):return False
                    def read(self):return json.dumps(self.value).encode()

                def fetch(request, timeout):
                    self.assertEqual(timeout, 30)
                    url = request.full_url
                    if request.get_method() == 'POST':
                        requests.append(url)
                        self.assertTrue(url.endswith('/actions/jobs/9/rerun'))
                        return Response(None)
                    if url.endswith('/actions/runs/42'):return Response(run)
                    if '/actions/workflows/7/runs?' in url:
                        return Response({'workflow_runs': [{'id': 43 if case == 'obsolete' else 42}]})
                    if '/actions/runs/42/jobs?' in url:return Response({'jobs': jobs})
                    if '/check-runs/101/annotations?' in url:return Response(self.annotations)
                    self.fail('Unexpected API request: ' + url)

                event = Path(directory) / 'event.json'
                event.write_text(json.dumps({'workflow_run': observed}))
                with patch.dict(os.environ, {'GITHUB_ACTIONS': 'true',
                        'GITHUB_REPOSITORY': 'owner/repo', 'GITHUB_EVENT_PATH': str(event),
                        'GH_TOKEN': 'fixture-not-a-credential'}), \
                        patch('urllib.request.urlopen', fetch), patch('builtins.print'):
                    retry.main()
                self.assertEqual(len(requests), 1 if case == 'capacity' else 0)


if __name__ == '__main__':
    unittest.main()
