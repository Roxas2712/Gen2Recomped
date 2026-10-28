"""Acceptance for real-ROM coordinate steps and saved weather restoration."""
import re
def validate(result):
    assert result['preparedCoordWeatherFixture']and not result['continuousStory']and result['drawSaveAndRngPreserved']
    assert len(result['cases'])==7 and all(result['cases'].values())
    assert len(result['captures'])==len(set(result['captures']))==7
    ash,clear=result['corridor']['ash'],result['corridor']['clear']
    assert ash['trigger']==8 and clear['trigger']==2 and ash['x']-clear['x']==5 and ash['y']==clear['y']
    steps=result['steps'];assert len(steps)==11
    assert steps[0]['x']==clear['x']and steps[5]['x']==ash['x']and steps[-1]['x']==clear['x']
    assert all(s['saved']==s['active']==2 for s in steps[:5])
    assert all(s['saved']==s['active']==7 for s in steps[5:-1])
    assert steps[-1]['saved']==steps[-1]['active']==2
    assert result['saved']['weather']==7 and clear['x']<result['saved']['x']<ash['x']
    assert re.fullmatch(r'[a-f0-9]{64}',result['saved']['sha256'])
