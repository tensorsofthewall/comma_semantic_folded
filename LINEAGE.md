# semantic_folded lineage

This submission descends from public work on the comma.ai video compression challenge.

    PR #130 -> PR #133 -> PR #135 -> PR #140 -> PR #141 -> semantic_folded

- PR #130 (Fesal Fayed), PR #133 (JasonMo123) and PR #135 (Shreyan Mohanty) introduced the semantic renderer / pose-carrier architecture.
- PR #140 (adpena, `semantic_joint_ctxmix`) added the semantic edits, pose re-solve, pruned mixed-precision renderer, adaptive context mixing and carrier entropy representations.
- PR #141 (ExplodingCB) re-packed the PR #140 state with a `BLK2` block container. Its runtime is vendored unchanged in `submission/semantic_folded/external/pr141/` (only the files the decoder loads, plus the MIT `LICENSE`).

| Component | Provenance |
|---|---|
| Semantic-token architecture, renderer/HPAC/carrier code | inherited public lineage |
| Renderer starting state | inherited public lineage |
| HPAC starting state | inherited public lineage |
| Carrier starting state | inherited public lineage |
| Starting token map | inherited public lineage |
| Token/map refinement, token coder context warp | this work |
| Quantized frame latent | this work |
| HPAC row packing (`RP1`) | this work |
| `RID1` / `RID2` renderer folds | this work |
| Precision / state packing | this work |
| Final discrete polish | this work |

The fitted state in the archive (renderer, HPAC, carrier, token map) starts from the inherited public state and was then modified; it is not independent of it. Later public submissions (e.g. #146) are prior art only and are not ancestors of this state.

Upstream license: MIT, Copyright (c) 2026 comma.ai (see `LICENSE`).
