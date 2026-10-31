"""Read the driver's post-ledger receipt without parsing its full live trace.

The driver publishes this tiny receipt only after atomically replacing the
complete report. Older drivers keep the existing report-based admission.
"""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.

def published_receipt(read_json, state, queue, identity):
    terminal=bool(queue)and queue[-1].get('op')in('finish','verify-continue')
    if not terminal:
        try:
            ack=read_json('story-published.json')
        except FileNotFoundError:
            ack=None
        if (isinstance(ack,dict)and type(ack.get('format'))is int and ack['format']==1 and ack.get('identity')==identity
                and type(ack.get('seq'))is int and 1<=ack['seq']<=state['seq']and ack['seq']<=len(queue)
                and isinstance(ack.get('outcome'),str)):
            return {'seq':ack['seq'],'outcome':ack['outcome'],'passed':False}
    report=read_json('result.json')
    row=report['commands'][-1]if report['commands']else None
    return {'seq':row['seq']if row else 0,'outcome':row['outcome']if row else None,
            'passed':terminal and report['status']=='pass'}
