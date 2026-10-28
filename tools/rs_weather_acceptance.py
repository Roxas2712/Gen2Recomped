"""Shared acceptance contract for the prepared native weather fixture."""
def validate(result):
    assert result['preparedWeatherFixture']and not result['continuousStory']and result['drawSaveAndRngPreserved']
    assert len(result['cases'])==7 and all(result['cases'].values())
    assert len(result['captures'])==len(set(result['captures']))==19
    assert set(result['snapshots'])=={str(i)for i in range(15)}
    assert all(row['curr']==int(key)and row['initialized']for key,row in result['snapshots'].items())
    assert result['snapshots']['7']['ash']and result['snapshots']['8']['sandstorm']
    assert result['snapshots']['3']['rainVisible']==10 and result['snapshots']['4']['snow']==16
    assert len(result['cycles'])==8
    assert {(row['route'],row['stage'])for row in result['cycles']}=={(r,s)for r in(20,21)for s in range(4)}
    assert set(result['audio'])=={'SE_RAIN','SE_THUNDERSTORM','SE_DOWNPOUR','SE_RAIN_STOP'}
    assert all(row['nonzeroPCM']for row in result['audio'].values())
