/// Örnek JSON — uygulamayı ilk açışta denemek için.
const String sampleJson = '''
{
  "status": true,
  "errorCode": null,
  "operation": null,
  "httpStatus": 200,
  "desc": "Route planned successfully.",
  "result": {
    "mode": "TRANSIT",
    "accessibility_profile_applied": "physical",
    "accessibility_mode": "strict",
    "wheelchair_enabled": true,
    "routes_total": 5,
    "origin": {
      "lat": 40.745358,
      "lng": 29.943425,
      "name": "START",
      "stop_location_id": null
    },
    "destination": {
      "lat": 40.74535801389457,
      "lng": 29.943425188038823,
      "name": "END",
      "stop_location_id": null
    },
    "routes": [
      {
        "route_id": "r-1",
        "duration_min": 42,
        "distance_km": 12.4,
        "created_at": "2026-07-06T09:30:00Z",
        "legs": [
          {"mode": "WALK", "duration_min": 5, "line": null},
          {"mode": "BUS", "duration_min": 30, "line": "34AS"}
        ]
      },
      {
        "route_id": "r-2",
        "duration_min": 55,
        "distance_km": 14.0,
        "created_at": "2026-07-06T09:31:00Z",
        "legs": []
      }
    ]
  }
}
''';
