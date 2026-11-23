"""TecAlliance VIS VIN adapter and loopback WSGI entry point for a licensed pilot."""

import json
import os
import re
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener
from wsgiref.simple_server import make_server

VIS = "https://vehicle-identification.tecalliance.services/api/v1/vin"
VIN = re.compile(r"[A-HJ-NPR-Z0-9]{17}", re.ASCII)
COUNTRY = re.compile(r"[A-Z]{2}", re.ASCII)


class CatalogUnavailable(Exception):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        return None


def text(value):
    return value.strip() if isinstance(value, str) else ""


def as_ref(kind, value):
    if type(value) is int and value > 0:
        return f"tecdoc:{kind}:{value}"
    return ""


def map_vis_response(body, vin):
    """Map suggestions without inventing a model year from registration dates."""
    rows = body.get("vehicles", [])
    if not isinstance(rows, list):
        raise CatalogUnavailable
    matches = {}
    for row in rows[:100]:
        if not isinstance(row, dict):
            continue
        info = row.get("vehicleInformation")
        if not isinstance(info, dict) or info.get("restrictedForCurrentCountry") is True:
            continue
        echoed = text(info.get("vin")).upper()
        if echoed and echoed != vin:
            continue
        brand, model = text(info.get("make")), text(info.get("model"))
        if not brand or not model:
            continue
        ref = as_ref("k", info.get("ktype")) or as_ref("n", info.get("ntype"))
        engine = row.get("engine")
        codes = sorted({text(item.get("code")) for item in engine if isinstance(item, dict)}
                       - {""}) if isinstance(engine, list) else []
        variant = " · ".join(filter(None, [text(info.get("fullModel")), "/".join(codes)]))
        item = {
            "brand": brand, "model": model, "variant": variant, "year": None,
            "matchedIdentifier": echoed, "source": "TecAlliance VIS",
        }
        matches[(ref, brand, model, variant, echoed)] = item

    # Multiple mappings or engine options are candidates, not verified fitment.
    result = []
    for (ref, _, _, variant, echoed), item in matches.items():
        exact = (len(rows) == 1 and len(matches) == 1 and ref and echoed == vin and variant
                 and isinstance(rows[0].get("engine"), list) and len(rows[0]["engine"]) == 1)
        result.append(dict(item, id=ref if exact else "",
                           verification="exact" if exact else "candidate"))
    return result[:30]


def lookup_vin(vin, country, api_key, provider="", *, opener=None):
    if not VIN.fullmatch(vin) or not COUNTRY.fullmatch(country):
        raise ValueError("Invalid VIN or ISO country")
    if not api_key:
        raise CatalogUnavailable
    headers = {"Accept": "application/json", "X-API-Key": api_key}
    if provider:
        headers["X-Provider"] = provider
    query = urlencode({"lang": "en"})
    request = Request(f"{VIS}/{country}/{quote(vin, safe='')}?{query}", headers=headers)
    try:
        with (opener or build_opener(NoRedirect())).open(request, timeout=7) as response:
            body = json.loads(response.read(1024 * 1024 + 1))
        if not isinstance(body, dict):
            raise CatalogUnavailable
        return map_vis_response(body, vin)
    except HTTPError as error:
        if error.code == 404:
            return []
        raise CatalogUnavailable from None
    except (URLError, TimeoutError, OSError, ValueError):
        raise CatalogUnavailable from None


def application(env, start_response):
    if env["REQUEST_METHOD"] == "POST" and env["PATH_INFO"] in ("/frame", "/parts"):
        status, body = "200 OK", {"results": []}
    elif env["REQUEST_METHOD"] != "POST" or env["PATH_INFO"] != "/vin":
        status, body = "404 Not Found", {"error": "route unavailable"}
    else:
        try:
            length = int(env.get("CONTENT_LENGTH") or 0)
            if not 0 < length <= 4096:
                raise ValueError
            data = json.loads(env["wsgi.input"].read(length))
            if not isinstance(data, dict):
                raise ValueError
            vin = text(data.get("vin")).upper()
            if not VIN.fullmatch(vin):
                raise ValueError
            country_map = json.loads(os.getenv("TECALLIANCE_COUNTRY_MAP", "{}"))
            if not isinstance(country_map, dict):
                raise CatalogUnavailable
            country = text(country_map.get(text(data.get("market"))) or
                           os.getenv("TECALLIANCE_COUNTRY")).upper()
            if not COUNTRY.fullmatch(country):
                raise CatalogUnavailable
            body = {"results": lookup_vin(vin, country, os.getenv("TECALLIANCE_API_KEY", ""),
                                          os.getenv("TECALLIANCE_PROVIDER", ""))}
            status = "200 OK"
        except ValueError:
            status, body = "400 Bad Request", {"error": "invalid request"}
        except CatalogUnavailable:
            status, body = "503 Service Unavailable", {"error": "catalog unavailable"}
    payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
    start_response(status, [("Content-Type", "application/json; charset=utf-8"),
                            ("Content-Length", str(len(payload))), ("Cache-Control", "no-store")])
    return [payload]


if __name__ == "__main__":
    with make_server("127.0.0.1", 8765, application) as server:
        server.serve_forever()
