import io
import json
import os
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

import tecalliance_vis as vis


VIN = "WDB2110061A000000"


def vehicle(vin=VIN, ktype=123):
    return {
        "vehicleInformation": {
            "vin": vin, "make": "Mercedes-Benz", "model": "E-Class",
            "fullModel": "E 220 CDI", "ktype": ktype,
            "salesStartDate": "200202", "lastRegistrationDate": "20251030",
        },
        "engine": [{"code": "OM646"}],
    }


class VisTest(unittest.TestCase):
    def test_unique_match_maps_type_without_guessing_year(self):
        result, = vis.map_vis_response({"vehicles": [vehicle()]}, VIN)
        self.assertEqual(result["id"], "tecdoc:k:123")
        self.assertEqual(result["verification"], "exact")
        self.assertIsNone(result["year"])

    def test_ambiguous_mappings_and_wrong_identifier_cannot_verify_fitment(self):
        result = vis.map_vis_response({"vehicles": [vehicle(), vehicle(ktype=321)]}, VIN)
        self.assertEqual([item["verification"] for item in result], ["candidate", "candidate"])
        self.assertFalse(any(item["id"] for item in result))
        self.assertEqual(vis.map_vis_response({"vehicles": [vehicle("WDB2110061A000001")]}, VIN), [])

    def test_client_uses_official_endpoint_and_reports_missing_licence(self):
        class Opener:
            def open(self, request, timeout):
                if not request.full_url.endswith(f"/api/v1/vin/DE/{VIN}?lang=en"):
                    raise AssertionError(request.full_url)
                if request.get_header("X-api-key") != "fixture":
                    raise AssertionError("Wrong auth header")
                raise HTTPError(request.full_url, 401, "Unauthorized", {}, None)

        with self.assertRaises(vis.CatalogUnavailable):
            vis.lookup_vin(VIN, "DE", "fixture", opener=Opener())

    def test_wsgi_smoke(self):
        status = []
        request = json.dumps({"vin": VIN, "market": "EU"}).encode()
        with patch.dict(os.environ, {"TECALLIANCE_COUNTRY_MAP": '{"EU":"DE"}',
                                    "TECALLIANCE_API_KEY": "fixture"}):
            with patch("tecalliance_vis.lookup_vin", return_value=[]) as lookup:
                data = b"".join(vis.application({
                    "REQUEST_METHOD": "POST", "PATH_INFO": "/vin",
                    "CONTENT_LENGTH": str(len(request)), "wsgi.input": io.BytesIO(request),
                }, lambda code, _: status.append(code)))
        self.assertEqual(status, ["200 OK"])
        self.assertEqual(json.loads(data), {"results": []})
        lookup.assert_called_once_with(VIN, "DE", "fixture", os.getenv("TECALLIANCE_PROVIDER", ""))
