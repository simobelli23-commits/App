#!/usr/bin/env python3
"""Test di integrazione del motore Valhalla REALE sugli scenari sintetici.

Per ogni scenario calcola il percorso con costing `motor_scooter`
(top_speed 45) e verifica, tramite /trace_attributes, che la scorciatoia
vietata NON venga usata. Per evitare test che passano "a vuoto", ogni
scenario ha un CONTROLLO: con un costing a cui la scorciatoia e' consentita
(auto, bicycle o pedestrian) il motore DEVE usarla; se non la usa, la fixture
non dimostra nulla e il test e' marcato INVALID.

Uso:
  python -I scripts/build_fixture_network.py routing/valhalla/fixtures/scenarios.osm.pbf
  python -I scripts/valhalla_integration_test.py routing/valhalla/fixtures/scenarios.osm.pbf

Richiede: pyvalhalla (MIT) e pyosmium. Output: routing/valhalla/fixtures/results.json
"""
import json
import os
import subprocess
import sys
import tempfile

from valhalla import Actor, get_config

# atteso per il ciclomotore: "avoid" = non deve usare la scorciatoia,
# "use" = deve usarla, "no_route" = nessun percorso; "info" = solo registrazione
EXPECT = {
    "motorway": ("avoid", "auto"),
    "motorway_only": ("no_route", "auto"),
    "motorroad": ("avoid", "auto"),
    "trunk_plain": ("info", "auto"),  # ambiguo: il validatore app lo esclude
    "oneway_against": ("avoid", "pedestrian"),
    "oneway_except_bike": ("avoid", "bicycle"),
    "oneway_yes_reversed": ("avoid", "pedestrian"),
    "trunk_moped_yes": ("info", "auto"),
    "cycleway": ("avoid", "bicycle"),
    "footway": ("avoid", "pedestrian"),
    "private": ("avoid", "pedestrian"),
    "moped_no": ("avoid", "auto"),
    "motor_vehicle_no": ("avoid", "pedestrian"),
    "turn_restriction": ("avoid", "pedestrian"),
    "residential_ok": ("use", "auto"),
}


def build_tiles(pbf: str, workdir: str) -> str:
    tile_dir = os.path.join(workdir, "tiles")
    os.makedirs(tile_dir, exist_ok=True)
    cfg = get_config(tile_extract="", tile_dir=tile_dir)
    cfg["mjolnir"]["reclassify_links"] = False  # vedi ROUTING_RULES.md
    cfg_path = os.path.join(workdir, "valhalla.json")
    with open(cfg_path, "w") as f:
        json.dump(cfg, f)
    import valhalla
    exe = os.path.join(os.path.dirname(valhalla.__file__), "bin", "valhalla_build_tiles")
    subprocess.run([exe, "-c", cfg_path, pbf], check=True, stdout=subprocess.DEVNULL)
    return cfg_path


def route_names(actor, sc, costing):
    q = {
        "locations": [sc["origin"], sc["destination"]],
        "costing": costing,
        "costing_options": {"motor_scooter": {"top_speed": 45}},
    }
    try:
        r = actor.route(q)
    except Exception as e:  # pyvalhalla solleva su errori del motore
        return None, str(e)
    if isinstance(r, str):
        r = json.loads(r)
    shape = r["trip"]["legs"][0]["shape"]
    t = actor.trace_attributes({
        "encoded_polyline": shape, "shape_match": "edge_walk", "costing": costing,
        "filters": {"attributes": ["edge.names", "edge.road_class", "edge.use"], "action": "include"},
    })
    if isinstance(t, str):
        t = json.loads(t)
    names = [n for e in t.get("edges", []) for n in e.get("names", [])]
    classes = [e.get("road_class") for e in t.get("edges", [])]
    return {"names": names, "classes": classes}, None


def main(pbf: str) -> int:
    manifest = json.load(open(pbf.replace(".osm.pbf", ".manifest.json"), encoding="utf-8"))
    results, failures = [], 0
    with tempfile.TemporaryDirectory() as wd:
        actor = Actor(build_tiles(pbf, wd))
        for sid, sc in manifest.items():
            expect, control_costing = EXPECT[sid]
            used = lambda res: res is not None and any(n in res["names"] for n in sc["shortcut_names"])
            moped, moped_err = route_names(actor, sc, "motor_scooter")
            ctrl, ctrl_err = route_names(actor, sc, control_costing)
            control_ok = used(ctrl)
            if expect == "avoid":
                ok = moped is not None and not used(moped)
            elif expect == "use":
                ok = used(moped)
            elif expect == "no_route":
                ok = moped is None
            else:
                ok = True
            outcome = "INFO" if expect == "info" else (
                "INVALID" if not control_ok else ("PASS" if ok else "FAIL"))
            if outcome in ("FAIL", "INVALID"):
                failures += 1
            results.append({
                "scenario": sid, "description": sc["description"], "expect": expect,
                "outcome": outcome, "moped": moped, "moped_error": moped_err,
                "control_costing": control_costing, "control_used_shortcut": control_ok,
                "control_error": ctrl_err, "verification": "automatica (rete sintetica)",
            })
            print(f"{outcome:8} {sid:22} {sc['description']}")
    out = os.path.join(os.path.dirname(pbf), "results.json")
    json.dump(results, open(out, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    print(f"\n{len(results)} scenari, {failures} falliti/invalidi. Dettagli: {out}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
