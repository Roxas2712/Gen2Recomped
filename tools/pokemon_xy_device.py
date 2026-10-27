"""Read the measured native startup qualification for each installed edition."""
import json
from pokemon_xy_library import WORK
if __name__=="__main__":
    for edition in ("x","y"):
        path=WORK/"device-tests"/(edition+".json")
        print(edition.upper()+": "+(json.dumps(json.loads(path.read_text()),ensure_ascii=False) if path.is_file() else "not tested"))
