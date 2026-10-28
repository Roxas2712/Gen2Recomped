"""Strict comparison with one documented frozen-reference Mist difference."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
def equal(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(equal(left[k], right[k]) for k in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(equal(a, b) for a, b in zip(left, right))
    return left == right


def compare_rows(left, right, effect):
    result = dict(equal=False, matching_expected=False,
                  known_reference_differences=[], unclassified_differences=[])
    if not isinstance(left, list) or not isinstance(right, list) or not left or len(left) != len(right):
        result['unclassified_differences'].append(dict(reason='missing or mismatched worker rows'))
        return result
    result['equal'] = equal(left, right)
    for index, (a, b) in enumerate(zip(left, right)):
        if equal(a, b):
            continue
        known = (effect == 'mist' and isinstance(a, dict) and isinstance(b, dict)
                 and a.get('label') == b.get('label') == 'guaranteed secondary protected'
                 and type(a.get('speed')) is int and a['speed'] == -1
                 and type(b.get('speed')) is int and b['speed'] == 0)
        adjusted = dict(a) if known else None
        if adjusted is not None:
            adjusted['speed'] = 0
        if known and equal(adjusted, b):
            result['known_reference_differences'].append(dict(
                index=index, label=a['label'], field='speed', reference=-1, native=0))
        else:
            result['unclassified_differences'].append(dict(index=index))
    result['matching_expected'] = not result['unclassified_differences']
    return result
