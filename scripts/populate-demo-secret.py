"""Populate a disposable demo secret outside Terraform without logging its value."""
import json
import secrets
import subprocess

import boto3


def main():
    arn = subprocess.check_output([
        "tools/terraform.exe", "-chdir=terraform/envs/dev", "output", "-raw", "demo_secret_arn"
    ], text=True).strip()
    # Export credentials only into this process's memory; never print them.
    credentials = json.loads(subprocess.check_output([
        "aws", "configure", "export-credentials", "--format", "process"
    ], text=True))
    client = boto3.client("secretsmanager", region_name="us-east-1",
                         aws_access_key_id=credentials["AccessKeyId"],
                         aws_secret_access_key=credentials["SecretAccessKey"],
                         aws_session_token=credentials.get("SessionToken"))
    client.put_secret_value(SecretId=arn, SecretString="demo-only-" + secrets.token_hex(24))
    print("Demo secret populated; value not displayed.")


if __name__ == "__main__":
    main()
