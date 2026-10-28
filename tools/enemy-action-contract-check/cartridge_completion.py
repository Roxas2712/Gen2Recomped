"""Explicit cartridge expectations for two gaps in the pinned reference.

See completion-oracle.md. Raw reference observations remain in the report;
every corrected row still undergoes a complete strict value comparison.
"""
from copy import deepcopy


def expected_completion(reference, version, mode):
    if version not in ('firered', 'emerald') or mode not in ('post_hit_items_execution', 'spit_up'):
        raise ValueError('unsupported cartridge completion contract')
    if not isinstance(reference, list):
        raise ValueError('completion observations must be a row list')
    expected, corrections = deepcopy(reference), []
    for index, row in enumerate(expected):
        if not isinstance(row, dict) or not isinstance(row.get('case'), str):
            raise ValueError('unknown completion observation schema')
        rules = []
        if mode == 'post_hit_items_execution' and row['case'] == 'user_faint':
            if not isinstance(row.get('state'), list) or len(row['state']) not in (2, 4):
                raise ValueError('missing faint battler states')
            for battler in row['state']:
                if not isinstance(battler, dict) or type(battler.get('hp')) is not int:
                    raise ValueError('unknown faint battler state')
                if battler['hp'] == 0 and 'status' in battler:
                    if battler['status'] not in ('SLP', 'PSN', 'TOX', 'BRN', 'PAR', 'FRZ'):
                        raise ValueError('unknown major status on fainted battler')
                    del battler['status']
                    rules.append('clear-major-status-on-faint')
        elif mode == 'spit_up' and row['case'] == 'wonder-guard' and row.get('count') in (1, 2, 3):
            hits = row.get('hits')
            if (type(row.get('count')) is not int or type(row.get('amount')) is not int or row['amount'] <= 0
                    or not isinstance(hits, list) or len(hits) != 1
                    or not isinstance(hits[0],dict) or hits[0].get('move') != 'SPIT_UP' or hits[0].get('typeMult') != 10
                    or hits[0].get('amount') != row['amount'] or hits[0].get('substitute') is not False
                    or hits[0].get('crit') is not False or row.get('stockpile') != 0):
                raise ValueError('unknown neutral Spit Up reference outcome')
            row['amount'], row['hits'] = 0, []
            rules.append('spit-up-typecalc-respects-wonder-guard')
        if rules:
            corrections.append({'row': index, 'case': row['case'], 'rules': rules})
    return expected, corrections
