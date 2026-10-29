"""Resume the latest release after a never-started hosted Mac capacity failure.

Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
No checkout, artifact or annotation is executed by this controller.
"""
import json
import os
import re
import urllib.request
from pathlib import Path

WORKFLOW = 'RetroRecomped intermediate pre-release'
MAX_ATTEMPTS = 4


def eligible_run(run, repository, latest_id):
    return (
        run.get('name') == WORKFLOW
        and run.get('event') == 'workflow_dispatch'
        and run.get('status') == 'completed'
        and run.get('conclusion') == 'failure'
        and (run.get('head_repository') or {}).get('full_name') == repository
        and run.get('id') == latest_id
        and 0 < (run.get('run_attempt') or 0) < MAX_ATTEMPTS
    )


def capacity_job(job, annotations):
    labels = [str(v).lower() for v in job.get('labels', [])]
    messages = '\n'.join(str(a.get('message', '')) for a in annotations).lower()
    return (
        job.get('status') == 'completed'
        and job.get('conclusion') == 'cancelled'
        and not job.get('runner_name')
        and not job.get('steps')
        and any(v.startswith('macos-') for v in labels)
        and 'self-hosted' not in labels
        and 'the job was not acquired by runner of type hosted' in messages
        and 'capacity constraints' in messages
    )


def check_run_id(job, repository):
    prefix = 'https://api.github.com/repos/' + repository + '/check-runs/'
    url = job.get('check_run_url') or ''
    if not isinstance(url, str) or not url.lower().startswith(prefix.lower()):
        return None
    value = url[len(prefix):]
    return int(value) if value.isdecimal() else None


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise SystemExit('This controller only runs in GitHub Actions')
    repository = os.environ['GITHUB_REPOSITORY']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise SystemExit('Invalid repository identity')
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    observed = event['workflow_run']
    root = 'https://api.github.com/repos/' + repository

    def api(path, method='GET'):
        request = urllib.request.Request(root + path, method=method,
            data=b'{}' if method == 'POST' else None,
            headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
                'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
        return json.loads(body) if body else None

    run_id = int(observed['id'])
    run = api('/actions/runs/' + str(run_id))
    latest = api('/actions/workflows/' + str(int(run['workflow_id']))
        + '/runs?event=workflow_dispatch&per_page=1')['workflow_runs']
    latest_id = latest[0]['id'] if latest else None
    if (run.get('run_attempt') != observed.get('run_attempt')
            or not eligible_run(run, repository, latest_id)):
        print('No retry: obsolete, cancelled, active or exhausted release request')
        return
    jobs = []
    for page in range(1, 11):
        batch = api('/actions/runs/' + str(run_id)
            + '/jobs?filter=latest&per_page=100&page=' + str(page))['jobs']
        jobs.extend(batch)
        if len(batch) < 100:
            break
    else:
        raise SystemExit('Job enumeration exceeded the bounded release scope')
    if any(job.get('conclusion') == 'failure' for job in jobs):
        print('No retry: a job reported an actual failure')
        return
    for job in jobs:
        if job.get('conclusion') != 'cancelled' or job.get('runner_name') or job.get('steps'):
            continue
        check_id = check_run_id(job, repository)
        if check_id is None:
            continue
        annotations = api('/check-runs/' + str(check_id) + '/annotations?per_page=100')
        if capacity_job(job, annotations):
            api('/actions/jobs/' + str(int(job['id'])) + '/rerun', 'POST')
            print('Resubmitted capacity-only job', int(job['id']), 'for release run', run_id)
            return
    print('No retry: no never-started hosted Mac capacity failure')


if __name__ == '__main__':
    main()
