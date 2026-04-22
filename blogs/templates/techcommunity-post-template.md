# <Post title>

**Publication target:** Microsoft TechCommunity > Azure > Linux and Open Source Blog

## Summary

One paragraph that explains the problem, why AKS is a fit, and what the reader will achieve.

## Checked-in version contract

| Component | Checked-in version | Evidence in repo |
| --- | --- | --- |
| <Helm chart or runtime> | `<validated version>` | `<repo-relative path>` |

## Audience

- platform engineers
- cloud architects
- operators adopting AKS for stateful data platforms

## Outline

1. Why this workload on AKS
2. What the repo now provides
3. Checked-in version contract
4. Deployment path
5. Validation
6. Production-minded best practices
7. Cleanup and next steps

## Editorial notes

- keep Azure assumptions explicit
- call out stateful workload tradeoffs
- show both Bicep and Terraform entry points
- prefer internal/private exposure patterns unless there is a deliberate reason not to
- clearly name the checked-in chart and runtime versions the post was validated against
