"""Verify the AWS deployment and a denied CSI mount without displaying secrets."""
import copy
import json
import subprocess
import time

K = ["kubectl", "--kubeconfig", ".local/aws-kubeconfig", "--context", "weather-aws",
     "-n", "weather-dev"]


def kubectl(*args, payload=None):
    return subprocess.check_output(K + list(args), input=payload, text=True)


def apply(obj):
    return kubectl("apply", "-f", "-", payload=json.dumps(obj))


def main():
    deployment = json.loads(kubectl("get", "deployment", "weather", "-o", "json"))
    assert deployment["status"].get("readyReplicas") == 2
    pods = json.loads(kubectl("get", "pods", "-l", "app=weather", "-o", "json"))
    for pod in pods["items"]:
        if pod["metadata"].get("deletionTimestamp"):
            continue
        name = pod["metadata"]["name"]
        result = kubectl("exec", name, "--", "python", "-c",
                         "from pathlib import Path; "
                         "p=Path('/var/run/secrets/weather-demo/demo_token'); "
                         "assert p.read_text().startswith('demo-only-'); "
                         "print('secret readable; value withheld')")
        print(name, result.strip())
    print(kubectl("exec", "deployment/weather", "--", "python", "-c",
                  "import json,urllib.request; b='http://weather'; "
                  "print('health',urllib.request.urlopen(b+'/health').status); "
                  "print('ready',urllib.request.urlopen(b+'/ready').status); "
                  "print('version',urllib.request.urlopen(b+'/version').read().decode()); "
                  "print('weather',json.load(urllib.request.urlopen(b+'/api/weather?location_id=2337639'))['city'])"))
    denied_name = "weather-denied"
    spec = copy.deepcopy(deployment["spec"]["template"]["spec"])
    spec["serviceAccountName"] = denied_name
    spec["restartPolicy"] = "Never"
    # No app=weather label: this negative-test pod cannot become a Service endpoint.
    try:
        apply({"apiVersion": "v1", "kind": "ServiceAccount",
               "metadata": {"name": denied_name, "namespace": "weather-dev"},
               "automountServiceAccountToken": False})
        apply({"apiVersion": "v1", "kind": "Pod",
               "metadata": {"name": denied_name, "namespace": "weather-dev"}, "spec": spec})
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            pod = json.loads(kubectl("get", "pod", denied_name, "-o", "json"))
            if any(s.get("ready") for s in pod["status"].get("containerStatuses", [])):
                raise AssertionError("Unassociated ServiceAccount unexpectedly read the secret")
            events = json.loads(kubectl("get", "events", "--field-selector",
                                      f"involvedObject.name={denied_name}", "-o", "json"))
            for event in events["items"]:
                message = event.get("message", "")
                if event.get("reason") == "FailedMount" and any(
                    term in message.lower() for term in ["accessdenied", "access denied", "association", "not authorized"]
                ):
                    print("PASS: unassociated ServiceAccount failed the CSI secret mount")
                    print(message)
                    return
            time.sleep(3)
        raise AssertionError("No identity-related FailedMount evidence observed within 120 seconds")
    finally:
        kubectl("delete", "pod", denied_name, "--ignore-not-found", "--wait=false")
        kubectl("delete", "serviceaccount", denied_name, "--ignore-not-found")


if __name__ == "__main__":
    main()
