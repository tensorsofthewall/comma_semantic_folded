# semantic_folded

My submission to [comma.ai's video compression challenge](https://github.com/commaai/comma_video_compression_challenge/pull/150). The codec stores a compact semantic representation of driving video, with the aim of preserving the information needed by the challenge's segmentation and pose models.

**#1 on [comma.ai's official video compression leaderboard](https://comma.ai/leaderboard) as of October 21, 2026.** Official score: **0.134** (lower is better), with a **173,316-byte** submission archive.

[Submission](https://github.com/commaai/comma_video_compression_challenge/pull/150) · [Download the submitted archive](https://github.com/tensorsofthewall/comma_semantic_folded/releases/download/v1.0/archive.zip) · [Experiment write-up](WRITEUP.md) · [Lineage and credits](LINEAGE.md)

## How it works

The challenge scores decoded video by how closely SegNet and PoseNet behave on it, while also penalizing archive size. That makes preserving every RGB detail unnecessary.

The codec entropy-codes a semantic token map using a learned context model (HPAC). A small renderer reconstructs RGB frames from those tokens, while a separate low-rate carrier preserves information needed by PoseNet.

I built on the challenge's existing [public semantic-codec lineage](LINEAGE.md). My changes focused on improving the final rate-distortion score:

- Refining semantic tokens while accounting for their actual coding cost.
- Searching directly over quantized values and re-solving the pose carrier as the reconstruction changed.
- Folding redundant renderer operations algebraically to reduce stored parameters without changing the represented function.
- Packing HPAC and renderer state more tightly, with selective low-precision storage.

The [write-up](WRITEUP.md) covers what worked, what didn't, and why some seemingly promising improvements ended up costing more bits than they saved.

## Rebuild and verify

The submitted archive is available in the [v1.0 release](https://github.com/tensorsofthewall/comma_semantic_folded/releases/tag/v1.0). Its SHA-256 is:

```text
b1b94e987e9430382e00e11d8f2a5402ffa5ed5788e7f4c4e90e59b046900eb6
```

Rebuild the exact archive from the stored sections in `pieces/` and verify it:

```bash
./rebuild.sh
./verify.sh
```

This recreates the submitted archive byte-for-byte. It does not rerun training or compression from the original video, and it doesn't require a GPU.

To decode the archive:

```bash
bash submission/semantic_folded/inflate.sh <archive_dir> <output_dir> submission/semantic_folded/public_test_video_names.txt
```

`<archive_dir>` must contain `archive.zip`. Decoding writes `<output_dir>/0.raw` and requires a CUDA GPU, PyTorch, NumPy and a C compiler. Set `PYTHON` to choose the interpreter. To also verify the decoded output, run:

```bash
./verify.sh --decode <archive_dir> <output_dir>
```

## Credits

The starting semantic architecture and fitted state came from public challenge submissions [#130](https://github.com/commaai/comma_video_compression_challenge/pull/130), [#133](https://github.com/commaai/comma_video_compression_challenge/pull/133), [#135](https://github.com/commaai/comma_video_compression_challenge/pull/135), [#140](https://github.com/commaai/comma_video_compression_challenge/pull/140) and [#141](https://github.com/commaai/comma_video_compression_challenge/pull/141). See [LINEAGE.md](LINEAGE.md) for detailed attribution and [WRITEUP.md](WRITEUP.md) for the experiment history.
