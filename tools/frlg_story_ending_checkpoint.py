# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""Qualify an owned ordinary FRLG Hall autosave without claiming a menu SAVE."""
from copy import deepcopy
import re


def qualify(edition, run_name, verification, report, checkpoint):
    assert edition in ("firered", "leafgreen")
    assert run_name.startswith("gen2recomp-qa-" + edition + "-")
    assert verification["edition"] == report["edition"] == edition
    identity = "oasc-edition-qa-" + run_name[len("gen2recomp-qa-"):]
    assert verification["identity"] == identity
    assert verification["status"] == "pass" and verification["exitCode"] == 0
    assert verification["frozenSourceUnchanged"] is True
    assert verification["externalSaveRecoveryDisabled"] is True
    assert verification["allModsDisabled"] is True
    assert report["status"] == "pass"
    for key in ("continuousFromNewGame", "noTeleport", "noPartyInjection", "noDirectStoryFlagEdits",
                "parcelObtained", "parcelReturned", "pokedexObtained", "brockTmRewardObserved"):
        assert report[key] is True, "Ordinary story provenance is incomplete: " + key
    assert report["starter"]["level"] == 5
    assert checkpoint["sourceRun"] == run_name and checkpoint["profileIdentity"] == identity
    assert checkpoint["sourceCommit"] == verification["sourceCommit"]
    assert checkpoint["saveKind"] == "native-frlg-hall-of-fame"
    assert checkpoint["producedThroughNormalSaveMenu"] is False
    assert checkpoint["personalSave"] is False
    assert re.fullmatch(r"[0-9a-f]{64}", checkpoint["sha256"])
    assert re.fullmatch(r"profiles/guest/saves/" + edition + r"/slot[1-9][0-9]*\.lua", checkpoint["saveRelativePath"])
    rows = report["commands"]
    assert rows and all(row["seq"] == index for index, row in enumerate(rows, 1))
    allowed = {"press", "hold", "wait", "step", "goto", "advance", "battle-attack", "shot", "finish"}
    assert all(row["input"]["op"] in allowed for row in rows)
    state = checkpoint["snapshotAfterEnding"]
    assert type(state["seq"]) is int and 1 <= state["seq"] <= len(rows)
    receipt = rows[state["seq"] - 1]["after"]
    # The idle heartbeat advances frames without rewriting an input receipt.
    # Every gameplay field must remain exactly equal to the completed receipt.
    assert state["frame"] >= receipt["frame"]
    assert {k: v for k, v in state.items() if k != "frame"} == {
        k: v for k, v in receipt.items() if k != "frame"}
    assert state["top"]["source"] == "src/ui/Gen3TitleFRLG.lua"
    assert state["flags"].get("EVENT_BEAT_CHAMPION_RIVAL") is True
    assert 1 <= len(state["party"]) <= 6
    assert all(1 <= mon["level"] <= 100 for mon in state["party"])
    assert state["savedGameCount"] >= 1
    before = rows[:state["seq"]]
    wins = [r["seq"] for r in before if r["after"]["flags"].get("FLAG_G3_04BC") is True]
    halls = [r["seq"] for r in before if r["after"]["top"].get("screenId") == "Gen3FrlgHallOfFame"]
    credits = [r["seq"] for r in before if r["after"]["top"].get("screenId") == "Gen3FrlgCredits"]
    assert wins and halls and credits and min(wins) < min(halls) < min(credits) < state["seq"]
    return {key: deepcopy(report[key]) for key in (
        "starter", "parcelObtained", "parcelReturned", "pokedexObtained", "brockTmRewardObserved")}
