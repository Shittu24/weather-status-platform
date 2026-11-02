"""Read ECR basic scan results for the runnable linux/amd64 release manifest.

Usage: python scripts/scan-release.py APP_COMMIT evidence/image-scan.json
Requires an authenticated AWS CLI. Exits nonzero when scanning is incomplete.
"""
import json
import os
import subprocess
import sys
from pathlib import Path


def aws(*args):
    result = subprocess.run(
        ["aws", "ecr", *args, "--region", "us-east-1", "--output", "json"],
        check=False, capture_output=True, text=True, encoding="utf-8",
        env={**os.environ, "PYTHONIOENCODING": "utf-8", "AWS_CLI_OUTPUT_ENCODING": "UTF-8"},
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout)


def main():
    tag = sys.argv[1]
    repo = "weather-status"
    image = aws("batch-get-image", "--repository-name", repo,
                "--image-ids", f"imageTag={tag}")["images"][0]
    digest = image["imageId"]["imageDigest"]
    manifest = json.loads(image["imageManifest"])
    runnable = digest
    if "manifests" in manifest:
        runnable = next(m["digest"] for m in manifest["manifests"]
                        if m.get("platform", {}).get("os") == "linux"
                        and m["platform"].get("architecture") == "amd64")
    scan = aws("describe-image-scan-findings", "--repository-name", repo,
               "--image-id", f"imageDigest={runnable}")
    if scan["imageScanStatus"]["status"] != "COMPLETE":
        raise RuntimeError(f"Scan is not complete: {scan['imageScanStatus']}")
    findings = scan["imageScanFindings"]
    report = json.dumps({
        "app_commit": tag, "release_digest": digest,
        "runnable_digest": runnable, "status": scan["imageScanStatus"],
        "completed_at": findings.get("imageScanCompletedAt"),
        "vulnerability_source_updated_at": findings.get("vulnerabilitySourceUpdatedAt"),
        "counts": findings.get("findingSeverityCounts", {}),
        "findings": findings.get("findings", []),
    }, indent=2)
    if len(sys.argv) > 2:
        Path(sys.argv[2]).write_text(report + "\n", encoding="utf-8")
        print(json.dumps({"release_digest": digest, "counts": findings.get("findingSeverityCounts", {})}))
    else:
        print(report)


if __name__ == "__main__":
    main()
