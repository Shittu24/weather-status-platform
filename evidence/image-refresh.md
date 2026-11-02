# Base image refresh and ECR rescan

Verified November 1, 2026 (US Eastern). This supersedes the initial scan in phase3.md; that file preserves the historical rollback exercise.

[App PR 2](https://github.com/Shittu24/weather-status-app/pull/2) updated Python 3.13.7 slim to Python 3.13.18 slim-trixie, pinned to registry digest `sha256:76baad6037690d6e8c4397fbcaef17bca6f19eecef822b708fe8fa3417d30bb5`.

[Release run 41373469780](https://github.com/Shittu24/weather-status-app/actions/runs/41373469780) passed lint, dependency audit, 26 tests, container smoke testing and ECR publishing. App commit: `d84dfe985bfdfca8ff711c3240c40ad358d14411`.

| ECR severity | Previous image | Refreshed image |
| --- | ---: | ---: |
| Critical | 11 | 0 |
| High | 59 | 7 |
| Medium | 53 | 15 |
| Low | 14 | 4 |

The completed ECR basic scan and individual findings are recorded in [image-scan.json](image-scan.json). Absence of a severity in the ECR counts means zero reported findings at scan time, not a guarantee against vulnerabilities.

The remaining high findings concern SQLite (4), glibc (2), and zlib (1). In a disposable container from the new pinned base, `apt-get update` followed by `apt-cache policy libc6 libsqlite3-0 zlib1g` showed installed versions equal to candidates:

- libc6: `2.41-12+deb13u4`
- libsqlite3-0: `3.46.1-7+deb13u2`
- zlib1g: `1:1.3.dfsg+really1.3.1-1+b1`

No newer versions of these packages were offered by the configured Debian repositories at verification time. Findings have not been suppressed or declared harmless. This update is suitable for continuing the local portfolio lab; reassess the remaining findings and available fixes before an AWS deployment. ECR basic scanning is not a full application or runtime security assessment.

To inspect future published releases using the authenticated AWS CLI:

```powershell
python scripts/scan-release.py d84dfe985bfdfca8ff711c3240c40ad358d14411 evidence/image-scan.json
```

The script resolves the linux/amd64 manifest inside the release index and requires a COMPLETE scan before writing a report. It reads scan-on-push results; it does not initiate a new scan of an old image.
