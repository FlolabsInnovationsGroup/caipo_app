"""Turns `flutter test --machine` output into GitHub annotations, one per failure."""
import json
import sys

tests = {}
suites = {}
failures = 0
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        event = json.loads(line)
    except ValueError:
        continue
    kind = event.get("type")
    if kind == "suite":
        suites[event["suite"]["id"]] = event["suite"].get("path") or ""
    elif kind == "testStart":
        test = event["test"]
        tests[test["id"]] = (test.get("name", ""), suites.get(test.get("suiteID"), ""), test.get("line"))
    elif kind == "error":
        name, path, line_no = tests.get(event.get("testID"), ("loading", "", None))
        message = (event.get("error") or "") + "\n" + (event.get("stackTrace") or "")
        message = message.strip()[:1500].replace("%", "%25").replace("\r", "").replace("\n", "%0A")
        where = "file=%s" % path.split("caipo_app/")[-1] if path else ""
        if line_no:
            where += ",line=%s" % line_no
        print("::error %s,title=%s::%s" % (where, name.replace(",", ";")[:200], message))
        failures += 1
print("failures reported: %d" % failures)
