# Phase 3 verification

## CI and registry

- [Initial release run](https://github.com/Shittu24/weather-status-app/actions/runs/41346405954): lint, dependency audit, 25 tests and Docker smoke test passed. First publish failed with ECR manifest HEAD 403. Adding repository-scoped `ecr:BatchGetImage` fixed publishing on rerun, matching [AWS push permissions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-push-iam.html).
- OIDC successfully assumed the publish role. Trust is restricted to repository ID 1442199725, main branch and release environment. No long-lived AWS keys were placed in GitHub.
- [Platform PR 1](https://github.com/Shittu24/weather-status-platform/pull/1) pinned the published digest. Argo synced platform revision `27dd8f0905dacbe2b89e219674beec805aa0e4c0` and reported Healthy/Synced.
- Internal Service `/version` returned app commit `8f24a6f2a39d4e0c058ba22a8f35323d67b62e69` in openmeteo mode.

## Failed-test gate

- [Deliberate failure](https://github.com/Shittu24/weather-status-app/actions/runs/41350632810) at commit `a008dce`: missing APP_COMMIT fixture failed pytest; publish was skipped. GitHub reported the PR merge state as `blocked` under the required verify check.
- [Corrected PR run](https://github.com/Shittu24/weather-status-app/actions/runs/41372488995) passed after setting the fixture. Local validation also passed 26 tests and Ruff.
- [App PR 1](https://github.com/Shittu24/weather-status-app/pull/1) was squash-merged only after passing checks, producing `4c68d42c91ec1e2fd540cb3cdd3e678e61560246`.

This is a solo portfolio workflow; PR history does not represent independent peer approval. A failed PR cannot publish by event policy, and main publishing additionally depends on verification succeeding.

## Promotion and Git revert

- [Second main release](https://github.com/Shittu24/weather-status-app/actions/runs/41372592023) passed verification and published digest `sha256:0ffa65160ff8003a017e240252fe26d56de35479eaa1a37fc0d4c6f4c5861860`.
- [Platform PR 2](https://github.com/Shittu24/weather-status-platform/pull/2) promoted that digest. Argo synced `db82427db9ed2d5ac0333aa3d1b6071e6d520316`, reported Healthy, and the Service returned app commit `4c68d42c91ec1e2fd540cb3cdd3e678e61560246`.
- [Platform PR 3](https://github.com/Shittu24/weather-status-platform/pull/3) reverted the promotion using `git revert`. Argo synced `6b4de6f928973382a9a66e3069a205c98cb4ff97`, reported Healthy/Synced, and both restored replicas returned `8f24a6f2a39d4e0c058ba22a8f35323d67b62e69`.
- After rollout settled, exactly two pods were Ready; Service health and readiness returned HTTP 200. An inspection briefly included a terminating old pod that disappeared before exec; the subsequent pod listing confirmed the final two replicas.
- Ilorin text search returned multiple places (HTTP 409 for ambiguous weather lookup). Autocomplete returned Ilorin, Kwara State with location ID 2337639, demonstrating why the city-selection UI is necessary. Weather lookup by that selected ID returned live Open-Meteo conditions successfully.

## Image security follow-up

ECR basic scanning completed for the runnable image manifest `sha256:6e721840ba1bf8e5f2c2dd67c204b33e3e478d6a9296f4a9ec096a77e28ef09a` referenced by the initial release index. Results on November 1, 2026 (US Eastern): 11 CRITICAL, 59 HIGH, 53 MEDIUM and 14 LOW findings. Query the runnable manifest digest, not the OCI index, for basic scan findings.

These are scanner findings, not confirmation that every vulnerability is exploitable through this app. Nevertheless, the pinned base image requires updating and rescanning before an AWS deployment. The passing Python dependency audit does not cover OS packages. The local rollback demonstration intentionally leaves the original release running; it must not be described as vulnerability-free or production-ready.

## Scope

Argo controls a local kind cluster. ECR and IAM are real AWS resources. Terraform/EKS, automated pull-secret rotation, and an ECR vulnerability release gate are not implemented in Phase 3. Scan-on-push configuration alone is not evidence of a clean scan.
