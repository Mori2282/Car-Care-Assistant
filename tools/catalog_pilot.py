"""Check a consented, labelled vehicle sample against the licensed catalog gateway."""

import csv
import json
import os
import sys
from collections import Counter
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        return None


def normalized(value):
    return " ".join(str(value or "").casefold().split())


def part_number(value):
    return "".join(c for c in str(value or "").upper() if c.isalnum())


def query(endpoint, payload):
    req = Request(
        f"{BASE}/{endpoint}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with OPENER.open(req, timeout=12) as response:
        body = json.load(response)
    if not isinstance(body.get("results"), list):
        raise ValueError("Wrong response shape")
    return body["results"]


def evaluate(row):
    candidates = query("vin", {
        "vin": row["vin"].strip().upper(), "market": row["market"],
    })
    identity = [v for v in candidates if all(
        normalized(v.get(k)) == normalized(row[k]) for k in ("brand", "model", "year")
    )]
    if not identity:
        return "vehicle_missing_or_wrong"
    exact = [v for v in identity if v.get("id") and
             normalized(v.get("variant")) == normalized(row["variant"])]
    if not exact:
        return "model_only"
    if len({v["id"] for v in exact}) != 1:
        return "ambiguous_variant"
    vehicle = exact[0]
    if not row["oe"]:
        return "variant_matched"
    matches = query("parts", {
        "query": row["oe"], "vehicleId": vehicle["id"],
        "brand": row["brand"], "model": row["model"], "year": row["year"],
        "variant": row["variant"], "market": row["market"],
    })
    confirmed = [p for p in matches if p.get("fitmentConfirmed") is True]
    if any(p.get("vehicleId") != vehicle["id"] or
           part_number(p.get("oe")) != part_number(row["oe"]) for p in confirmed):
        return "unexpected_confirmed_part"
    expected = part_number(row.get("expected_part"))
    if any(not expected or part_number(p.get("number")) == expected for p in confirmed):
        return "fitment_confirmed"
    return "variant_matched_part_unverified"


if __name__ == "__main__":
    BASE = os.environ.get("CATALOG_API_URL", "").rstrip("/")
    parsed = urlsplit(BASE)
    if (len(sys.argv) != 2 or parsed.scheme != "https" or not parsed.hostname or
            parsed.username or parsed.password or parsed.query or parsed.fragment):
        sys.exit("Set an HTTPS CATALOG_API_URL and pass the private CSV path.")
    OPENER = build_opener(NoRedirect())
    counts = Counter()
    required = {"cohort", "vin", "market", "brand", "model", "year", "variant", "oe", "expected_part"}
    with open(sys.argv[1], newline="", encoding="utf-8-sig") as file:
        rows = csv.DictReader(file)
        if not required.issubset(rows.fieldnames or []):
            sys.exit("Missing expected CSV headers. See docs/catalog.md.")
        for row in rows:
            if row.get("cohort") not in {"EU_2000S", "CN_DOMESTIC", "CN_EXPORT", "GM_NA"}:
                sys.exit("Unknown cohort.")
            if not all((row.get(k) or "").strip() for k in ("vin", "brand", "model", "year", "variant")):
                sys.exit("Incomplete labelled pilot row.")
            try:
                outcome = evaluate(row)
            except (OSError, ValueError, TypeError, KeyError):
                outcome = "request_or_response_error"
            counts[(row["cohort"], outcome)] += 1
    if not counts:
        sys.exit("No pilot rows supplied.")
    for (cohort, outcome), count in sorted(counts.items()):
        print(f"{cohort} {outcome}: {count}")
    sys.exit(int(any(outcome == "unexpected_confirmed_part" for _, outcome in counts)))
