"""Opening evidence after the caller verifies the owned SAVE and input prefix."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
def inherited_progress(report, *, verified_failed_tail=False):
    starter=report.get('starter')
    assert isinstance(starter,dict) and starter.get('level')==5, 'Natural level-five starter proof required'
    keys=('parcelObtained','parcelReturned','pokedexObtained')
    for key in keys:
        assert report.get(key) is None or isinstance(report[key],bool), 'Opening evidence must be boolean'
    progress={key:bool(report.get(key)) for key in keys}
    assert not progress['parcelReturned'] or(progress['parcelObtained'] and progress['pokedexObtained']), 'Inconsistent parcel return evidence'
    original=(report.get('newGameThroughUI') is True and report.get('initialPartyEmpty') is True)
    inherited=(report.get('initialNewGameVerified') is True and report.get('continuedThroughUI') is True)
    if not all(progress.values()):
        assert inherited or(verified_failed_tail is True and original), 'Early SAVE requires verified original NEW GAME or an actual inherited UI continuation'
    result=dict(progress,starter=starter)
    if original or inherited:result['initialNewGameVerified']=True
    return result
