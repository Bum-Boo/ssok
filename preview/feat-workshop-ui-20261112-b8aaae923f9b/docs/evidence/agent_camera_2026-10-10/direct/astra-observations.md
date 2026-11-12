# Actual PNG inspection — native Astra, 2026-10-10

Independent visual inspection used the existing native `gpt-6-astra` worker. It directly viewed the
retained PNGs and read sidecars, not editor screenshots or a synthetic mock. This identifies the visual
inspector; it does not attest the backend identity of the separate Codex CLI actor.

## Direct R2 — five images

All images were640×480, episode `e902d0fe915c0b6099fb5c1c`, revision3/generation1. Actual file
SHA-256 matched each sidecar. The visible gray wall grew approximately355→380→406→435→443px
wide and shifted left/tilted. Floor remained visible in every frame; no editor UI was present.
The small last change does not establish its physical cause, contact or rest.

| Image | Frame / physics tick | SHA-256 |
|---|---|---|
| observation1 | 2 / 400 | d8d95db195c47fa4678c328790f5ace3916a69e29752e43f03a56944126732d6 |
| observation2 | 3 / 1014 | f43caeb2b488c401189b5b8da765ab18bd97f82f9b92d40cbb8a91d724664910 |
| observation3 | 4 / 1450 | 9a2c1dea4d6b0e27f7872cf3fea2d9181db985b89a99b3dff56f62bef23296bb |
| observation4 | 5 / 1904 | b15d89db502accabd0299b65a84677c3d13e40211bf2903ea8add3321bcae4fd |
| observation5 | 6 / 2416 | f86357957278f5041de03d4e7beb032162ecf307ecfd88d7898f94fe4fd79031 |

## Final Korean goal — two images

Both actual images were640×480, episode `1b3bcb30021f4df0d78cc7e0`, with matching file hashes.
Wall approximatelyx138–493→x107–471, width356→365px; the second upper boundary had a slight
tilt. Beige floor, sky and side geometry were clear; no editor UI. Actual image change is observed.

| Image | Frame / physics tick | SHA-256 |
|---|---|---|
| observation1 | 2 / 474 | b6bf0f14d44448ac50df34788a04696647d33246540c1fd2ee8b1564310d973f |
| observation2 | 3 / 962 | 7ff8ab7a6deb38738bcc9768a0b68083ff3883aead3ca3ffe311cf202a39c23d |

Distance, collision-free behavior, physical rest and navigation-goal success are not certified from
these still images. Measured settling/tool results are separate evidence in the event journals.
