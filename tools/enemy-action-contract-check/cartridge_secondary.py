"""Apply the two documented cartridge corrections to the pinned observations.

The reference stays read-only. This produces an explicit expected observation,
not an ignored-field comparison; damage, identities, events and RNG still have
to match. See secondary-oracle.md and the independent Gen3 protection contracts.
"""
from copy import deepcopy


STAT = {"attack-down": 0, "defense-down": 1, "speed-down": 2,
        "spatk-down": 3, "spdef-down": 4, "accuracy-down": 5}
PROTECTED = {"mist", "clear-body", "white-smoke", "certain-mist", "certain-clear-body"}


def expected_observations(reference, version, mode):
    if version not in ("firered", "emerald") or mode not in ("secondary", "secondary_execution"):
        raise ValueError("unsupported cartridge secondary contract")
    if not isinstance(reference, list):
        raise ValueError("secondary observations must be a row list")
    indexed = {}
    for row in reference:
        if not isinstance(row, dict) or not all(k in row for k in
                ("case", "effect", "chance", "word", "user", "draws", "result", "target", "attacker", "events")):
            raise ValueError("unknown secondary observation schema")
        key = (row["case"], row["effect"], row["chance"], row["word"])
        if key in indexed:
            raise ValueError("duplicate secondary observation")
        indexed[key] = row

    expected, corrections = [], []
    for index, row in enumerate(reference):
        result = deepcopy(row)
        reasons = []
        chance = row["chance"] * (2 if row["case"] == "serene-grace" else 1)
        if version == "emerald" and not row["case"].startswith("certain") and row["word"] == chance:
            # At the equality boundary Emerald does not apply any secondary.
            # The same fixture's 0% / word 99 case independently supplies its
            # no-effect state, including initial status and capped stages.
            baseline = indexed.get((row["case"], row["effect"], 0, 99))
            if baseline is None or baseline["events"] != []:
                raise ValueError("missing independent no-effect secondary control")
            for who in ("target", "attacker"):
                for field in ("status", "stages", "flinched", "confusion"):
                    if field not in baseline[who]:
                        raise ValueError("incomplete no-effect battler control")
                    result[who][field] = deepcopy(baseline[who][field])
            result["events"] = []
            result["result"] = "execution" if mode == "secondary_execution" else False
            positions = [i for i, draw in enumerate(row["draws"])
                         if draw.get("lo") == 0 and draw.get("hi") == 99]
            if len(positions) != 1:
                raise ValueError("ambiguous secondary chance RNG trace")
            # Preserve the actual damage and chance draws. Further draws in
            # this fixture belong only to confusion / Tri Attack's effect.
            result["draws"] = deepcopy(row["draws"][:positions[0] + 1])
            reasons.append("emerald-strict-chance-boundary")

        if row["case"] in PROTECTED and row["effect"] in STAT:
            stat = STAT[row["effect"]]
            stages = result["target"]["stages"]
            if len(stages) != 7 or type(stages[stat]) is not int or stages[stat] not in (-1, 0):
                raise ValueError("unexpected protected-stat reference state")
            stages[stat] = 0
            if mode == "secondary":
                result["result"] = False
            reasons.append("stat-protection-is-independent-of-probability")

        if result != row:
            corrections.append({"row": index, "case": row["case"], "effect": row["effect"],
                                "chance": row["chance"], "word": row["word"], "rules": reasons})
        expected.append(result)
    return expected, corrections
