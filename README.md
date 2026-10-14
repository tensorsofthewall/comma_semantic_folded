# semantic_folded

A semantic video codec submission for the comma.ai video compression challenge.

Local reference score: 0.13408959 · Archive: 173,316 bytes · SHA256 `b1b94e987e9430382e00e11d8f2a5402ffa5ed5788e7f4c4e90e59b046900eb6`

The name refers to the algebraic folding used to reduce the semantic renderer while preserving its behavior.

## Result

Local reference decode (RTX 2070S, cached-GT evaluator; **not** an official or T4 result):

| | |
|---|---|
| archive | `submission/semantic_folded/archive.zip`, 173,316 bytes |
| archive SHA256 | `b1b94e987e9430382e00e11d8f2a5402ffa5ed5788e7f4c4e90e59b046900eb6` |
| decoded raw SHA256 | `0ee1022894874d59ddae232f31f873a483adcd8745e42a91054d6843a4df6701` |
| Seg | 0.00015218947 |
| Pose | 1.20175e-6 |
| Local reference score | 0.13408959 |

T4 / official evaluation: not yet run.

## Approach

The video is represented by semantic tokens (a per-pixel class map, range-coded with a learned context model, HPAC) plus a low-rate pose carrier. A small semantic renderer synthesizes frames from the tokens, refined by a quantized frame latent and a few correction extensions. The archive is a single stored ZIP member holding the packed models, the token stream, a warp signal and extension records.

Starting from the inherited public state, this version refines the token map, applies renderer folding, stores parameters at lower precision with lossless packing (including HPAC row packing), and finishes with exact discrete optimization. The decoder handles the corresponding container formats (RP1, RID1, RID2).

## Decode

    bash submission/semantic_folded/inflate.sh <archive_dir> <output_dir> submission/semantic_folded/public_test_video_names.txt

`<archive_dir>` contains `archive.zip`. Writes `<output_dir>/0.raw` (uint8 RGB, 1200x874x1164x3). Needs a CUDA GPU, PyTorch (cuDNN on, TF32 off), numpy, and a C compiler (native backends are built into a temporary directory). Set `PYTHON` to choose the interpreter.

## Rebuild

    ./rebuild.sh

Assembles `build/archive.zip` from `pieces/` (see `pieces/plan.json`) and checks the SHA256. No GPU, videos or models needed.

## Writeup

See [WRITEUP.md](WRITEUP.md) for the experiments, what worked, what didn't, and the rate-distortion analysis.

## Verify

    ./verify.sh                                    # sizes, SHA256, manifest, rebuild, cmp
    ./verify.sh --decode <archive_dir> <out_dir>   # additionally decode and check the raw SHA256

## Lineage

See [LINEAGE.md](LINEAGE.md).
