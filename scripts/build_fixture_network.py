#!/usr/bin/env python3
"""Genera una rete stradale SINTETICA (non reale) in formato .osm.pbf per i
test di integrazione del motore Valhalla con il profilo ciclomotore.

Ogni scenario e' una rete isolata con:
  - un'origine S e una destinazione E;
  - una "scorciatoia" S->E con i tag dello scenario (es. autostrada);
  - opzionalmente una "deviazione" residenziale piu' lunga S->N1->N2->E.

Uso:  python -I scripts/build_fixture_network.py routing/valhalla/fixtures/scenarios.osm.pbf
Richiede: pyosmium (pip install osmium) - licenza BSD-2.
"""
import json
import os
import sys

import osmium

# (id, descrizione, tag scorciatoia, ha_deviazione, extra)
SCENARIOS = [
    ("motorway", "Autostrada come scorciatoia", {"highway": "motorway", "oneway": "yes"}, True, {}),
    ("motorway_only", "Destinazione raggiungibile solo in autostrada",
     {"highway": "motorway", "oneway": "yes"}, False, {}),
    ("motorroad", "Extraurbana principale (trunk + motorroad=yes)",
     {"highway": "trunk", "motorroad": "yes", "oneway": "yes"}, True, {}),
    ("trunk_plain", "Trunk senza motorroad (dato ambiguo)", {"highway": "trunk"}, True, {}),
    ("trunk_moped_yes", "Trunk con moped=yes esplicito", {"highway": "trunk", "moped": "yes"}, True, {}),
    ("oneway_against", "Senso unico contrario alla marcia",
     {"highway": "residential", "oneway": "-1"}, True, {}),
    ("oneway_except_bike", "Senso unico con eccezione solo bici",
     {"highway": "residential", "oneway": "yes", "oneway:bicycle": "no"}, True, {"reverse": True}),
    ("oneway_yes_reversed", "Senso unico (oneway=yes) digitalizzato contro la marcia",
     {"highway": "residential", "oneway": "yes"}, True, {"reverse": True}),
    ("cycleway", "Pista ciclabile come scorciatoia", {"highway": "cycleway"}, True, {}),
    ("footway", "Percorso pedonale come scorciatoia", {"highway": "footway"}, True, {}),
    ("private", "Strada privata come scorciatoia", {"highway": "service", "access": "private"}, True, {}),
    ("moped_no", "Divieto esplicito ai ciclomotori", {"highway": "residential", "moped": "no"}, True, {}),
    ("motor_vehicle_no", "Divieto ai veicoli a motore",
     {"highway": "residential", "motor_vehicle": "no"}, True, {}),
    ("turn_restriction", "Divieto di proseguire diritto al nodo intermedio",
     {"highway": "residential"}, True, {"restriction": "no_straight_on"}),
    ("residential_ok", "Controllo: scorciatoia residenziale consentita",
     {"highway": "residential"}, True, {}),
]

BASE_LAT, BASE_LON = 44.50, 10.70  # area fittizia a sud-ovest di Modena
STEP_LAT = 0.03


def build(path: str) -> dict:
    manifest = {}
    nid, wid, rid = 1, 1, 1
    nodes, ways, rels = [], [], []
    if True:  # costruzione in memoria
        for i, (sid, desc, tags, detour, extra) in enumerate(SCENARIOS):
            lat0 = BASE_LAT + i * STEP_LAT
            pts = {
                "S": (lat0, BASE_LON),
                "M": (lat0, BASE_LON + 0.010),
                "E": (lat0, BASE_LON + 0.020),
                "N1": (lat0 + 0.006, BASE_LON),
                "N2": (lat0 + 0.006, BASE_LON + 0.020),
                # tratti di accesso residenziali a S ed E (punti di snap)
                "S0": (lat0, BASE_LON - 0.004),
                "E0": (lat0, BASE_LON + 0.024),
            }
            ids = {}
            for name, (la, lo) in pts.items():
                ids[name] = nid
                nodes.append(osmium.osm.mutable.Node(id=nid, location=(lo, la), tags={}))
                nid += 1

            def way(nodes, t):
                nonlocal wid
                this = wid
                ways.append(osmium.osm.mutable.Way(id=this, nodes=[ids[n] for n in nodes], tags=t))
                wid += 1
                return this

            res = {"highway": "residential", "name": f"Via {sid} accesso"}
            way(["S0", "S"], res)
            way(["E", "E0"], res)
            if extra.get("reverse"):  # way digitalizzate E->M->S
                sc2 = way(["E", "M"], {**tags, "name": f"{sid} scorciatoia 2"})
                sc1 = way(["M", "S"], {**tags, "name": f"{sid} scorciatoia 1"})
            else:
                sc1 = way(["S", "M"], {**tags, "name": f"{sid} scorciatoia 1"})
                sc2 = way(["M", "E"], {**tags, "name": f"{sid} scorciatoia 2"})
            if detour:
                way(["S", "N1", "N2", "E"], {"highway": "residential", "name": f"Via {sid} deviazione"})
            if "restriction" in extra:
                rels.append(osmium.osm.mutable.Relation(
                    id=rid,
                    members=[("w", sc1, "from"), ("n", ids["M"], "via"), ("w", sc2, "to")],
                    tags={"type": "restriction", "restriction": extra["restriction"]}))
                rid += 1
            manifest[sid] = {
                "description": desc,
                "origin": {"lat": pts["S0"][0], "lon": pts["S0"][1]},
                "destination": {"lat": pts["E0"][0], "lon": pts["E0"][1]},
                "shortcut_tags": tags,
                "has_detour": detour,
                "shortcut_names": [f"{sid} scorciatoia 1", f"{sid} scorciatoia 2"],
            }
    # Ordine canonico OSM: nodi, poi way, poi relazioni.
    if os.path.exists(path):
        os.remove(path)
    with osmium.SimpleWriter(path) as w:
        for n in nodes:
            w.add_node(n)
        for x in ways:
            w.add_way(x)
        for r in rels:
            w.add_relation(r)
    return manifest


if __name__ == "__main__":
    out = sys.argv[1]
    m = build(out)
    with open(out.replace(".osm.pbf", ".manifest.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, indent=2, ensure_ascii=False)
    print(f"Scritti {len(m)} scenari in {out}")
