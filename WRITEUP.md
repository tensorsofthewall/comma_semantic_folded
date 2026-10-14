# semantic_folded

This is the writeup for my submission to the [comma.ai video compression challenge](https://github.com/commaai/comma_video_compression_challenge).

This challenge is interesting because the reconstructed video is not judged primarily by how it looks. It is judged by how closely two frozen downstream models behave on it: a SegNet and a PoseNet.

$\text{score} = 100 \cdot D_{\text{seg}} + \sqrt{10 \cdot D_{\text{pose}}} + 25R$ 
 
where \(R\) is the compressed size relative to the original video.

That changes the problem quite a bit. A visually cleaner reconstruction is not necessarily better, and an improvement to segmentation or pose is only useful if it costs few enough bits to improve the final score.

The final local result for `semantic_folded` is:

| Metric | Result |
|---|---:|
| Archive size | **173,316 bytes** |
| Seg distortion | **0.00015218947** |
| Pose distortion | **1.20175e-6** |
| Local reference score (RTX 2070 Super) | **0.13408959** |

## Starting point

This submission builds on the public semantic-codec line:

```text
#130 -> #133 -> #135 -> #140 -> #141 -> semantic_folded
```

PRs #130, #133, and #135 established much of the semantic-renderer and pose-carrier direction. PR #140 (`semantic_joint_ctxmix`) pushed that representation further with semantic edits, pose re-solving, mixed-precision renderer pruning, context mixing, and carrier changes. PR #141 (`semantic_blocks`) then repacked that state into a smaller block container.

The starting renderer, HPAC model, carrier state, and token map therefore come from that public lineage. The main areas I worked on were:

- further semantic-token refinement;
- exact search over quantized states;
- repeated pose-carrier re-solving;
- HPAC row packing;
- structural folding of the semantic renderer;
- selective lower-precision storage;
- tighter packing of the final representation;
- final rate-distortion polish.

I also looked at later public submissions, including #146 (`joint_hops`), as comparison points, but they are not ancestors of the baseline used here. For more exact provenance, see [`LINEAGE.md`](LINEAGE.md).



## What the codec stores

The main representation is a semantic token map rather than a conventional compressed RGB video.

The token map carries most of the information needed to preserve SegNet behavior; a learned context model (HPAC) predicts and range-codes those tokens. A small renderer converts the semantic representation back into RGB. It also receives a tiny quantized per-frame latent, which gives it a small amount of frame-specific freedom without requiring a conventional video residual.

Pose information is handled separately using a low-rate carrier. This matters because the information needed to preserve PoseNet is not exactly the same as the information needed to preserve SegNet.

At a high level, the final archive contains:

```text
semantic token stream
renderer + entropy-model state
pose carrier
warp signal
small correction extensions
```

The final packed payload is only about 173 KB.

---

# What I tried

## Conventional neural reconstruction

I initially treated the problem more like normal learned video compression: reconstruct the RGB frames and try to make those reconstructions better.

That was useful for understanding the evaluator, but it became obvious fairly quickly that RGB reconstruction quality was not a reliable proxy for the challenge metric. A frame could look decent and still move segmentation boundaries enough to score poorly. The reverse was also true: fairly noticeable image artifacts could be cheap if neither downstream model cared about them.

This was the first strong indication that the representation should be designed around the evaluator rather than around visual fidelity.

## Semantic representations

The public semantic submissions already pointed in a much better direction.

From that baseline I explored several ways of making the semantic representation smaller or more accurate:

- direct token-map optimization;
- learned replacements for the explicit token map;
- hierarchical semantic representations;
- tile dictionaries;
- temporal copy and delta coding;
- sparse corrections;
- boundary-oriented correction schemes;
- structured groups of token edits;
- direct rate-distortion search over token values.

The explicit semantic-token representation remained surprisingly difficult to beat.

## Renderer compression

The renderer was another obvious place to look for bytes.

I tried:

- low-rank factorization;
- narrower approximations;
- smaller student-style renderers;
- head factorization;
- pruning;
- lower precision;
- removing redundant affine state;
- algebraically folding adjacent operations.

The last approach ended up being much more useful than the approximate ones.

## Entropy coding

The token stream is the largest single part of the archive, so there was an obvious temptation to replace or heavily shrink the token predictor. I looked at:

- different temporal contexts;
- different coding orders;
- smaller predictors;
- lower-precision predictors;
- decoder-side adaptation;
- shared state between the renderer and entropy model;
- explicit temporal-copy modes;
- dictionaries and tiled representations;
- improved packing of the existing HPAC state.

There was clearly entropy headroom, but exploiting it without spending even more bytes on the predictor turned out to be difficult.

## Pose

The pose carrier was re-optimized repeatedly as the semantic representation changed. I also looked at more direct ways of correcting PoseNet, including image-space perturbations and compact low-rank corrections. There is measurable PoseNet headroom, but most of the useful corrections are expensive to describe.

## Exact discrete search

One of the more useful changes in methodology was to stop treating quantization as something that happens after optimization. If a parameter is ultimately stored as a 3-bit, 4-bit, or otherwise discrete value, then the real search space is discrete. I used direct search for:

- frame latent values;
- semantic token choices;
- carrier coefficients;
- selected low-bit renderer parameters.

In several places this worked better than optimizing a continuous proxy and rounding afterward.

---

# What worked

### 1. Optimizing for the evaluator

The biggest advantage comes from the semantic representation itself.

The task does not require reconstructing every detail of the source video. It requires preserving enough information for SegNet and PoseNet to behave similarly. That means many RGB details simply are not worth encoding.

The semantic token map captures the information needed by SegNet very efficiently, while the separate pose carrier covers information that the semantic representation does not preserve well enough for PoseNet. Once the representation matches the metric, the compression problem becomes much more manageable.

---

### 2. Exact optimization of quantized values

When a value is going to be stored as a small integer, searching over the actual stored values avoids a lot of ambiguity. A floating-point optimizer can improve a parameter without ever changing its quantized representation.

It can also find a good continuous point that lands in a poor quantization cell. Direct search avoids that mismatch; this worked especially well for the frame latent, carrier coefficients, and late token refinements.

---

### 3. Re-solving the pose carrier

The subsystems are coupled. A token change that helps segmentation changes the rendered image, which can move PoseNet. A renderer change can do the same. Because of that, I found it important to re-solve the pose carrier after meaningful changes elsewhere.

A candidate that looked worse immediately after a semantic change could become better once the carrier was re-optimized. Treating the semantic and pose sides independently left performance on the table.

---

### 4. Folding the renderer instead of approximating it

This is where the name `semantic_folded` comes from. Trying to replace the renderer with a smaller approximation was usually too destructive. The better approach was to remove redundant computation algebraically.

One important example was absorbing the token embedding into the following coordinate-mixing operation. Other bias, normalization, and affine terms could also be pushed into later operations so that they no longer needed to be stored independently.

This saved a meaningful amount of renderer state without asking a smaller network to approximate the original function. That distinction mattered, since a low-rank approximation saves parameters but introduces a new source of error. A valid fold removes parameters because they were mathematically redundant.

---

### 5. Selective low-precision storage

Lower precision also helped, but only when applied selectively. Some tensors were quite tolerant to losing a bit or two; others were not. Uniformly reducing everything to the same precision caused too much semantic damage. Testing individual tensor groups and keeping the sensitive ones at higher precision worked much better.

---

### 6. Lossless packing

A surprising amount of the late progress came from changes that did not alter the decoded representation at all, such as:

- tighter HPAC row packing;
- better layout of quantized state;
- removing redundant metadata;
- packing already-discrete values more efficiently;
- simplifying the container.

These improvements are particularly valuable because their distortion cost is exactly zero. At a total archive size around 170 KB, saving a few hundred bytes is already meaningful.

---

### 7. Rate-aware token edits

Late token optimization produced another useful observation: the best semantic edit is not always the edit that fixes the most pixels, its coding cost also matters.

Some edits were naturally easy for the existing context model to predict, especially when they agreed with temporal context. Those edits could improve segmentation for almost no additional rate, and occasionally even reduce the encoded token-stream size. That turned out to be more useful than trying to invent a separate macro or correction format.

---

# What did not work

### 1. Generic RGB reconstruction

This was fundamentally optimizing the wrong space. PSNR and visual quality were weak predictors of the actual score.

Since the downstream models care about particular structures in the image, a tiny change on a class boundary matters more than a larger RGB error somewhere else.

---

### 2. Replacing the token map with a neural generator

The semantic maps are highly structured, so a compact generator looks attractive. The problem was where its errors appeared; a generator could reproduce almost the entire map correctly, but the remaining mistakes tended to land on areas such as:

- boundaries;
- corners;
- junctions;
- thin structures.

These are exactly the places where small geometric errors can change SegNet output; very high token accuracy by itself was therefore not enough.

---

### 3. Low-rank renderer approximations

The renderer was already small enough that approximate compression had poor economics. A low-rank factorization might save several hundred bytes, but if it moved enough boundaries to create several hundred extra segmentation mismatches, the final score got worse.

The renderer did have redundancy, but it was just safer to remove that redundancy algebraically than to approximate it.

---

### 4. Explicit boundary corrections

Because most of the residual SegNet error sits around boundaries, a dedicated boundary correction stream seemed obvious, but addressing overhead was problematic. Such explicit corrections had to communicate some combination of:

- location;
- class;
- direction;
- shape;
- mask or run information.

For sparse, irregular errors, the metadata quickly costs more than the corrected pixels are worth.

---

### 5. Tiled and hierarchical semantic codecs

Large regions of the token maps are highly redundant, so tile-based and hierarchical representations initially looked promising. In practice, the existing context model already compresses those easy regions well. The difficult information is the irregular boundary detail left over.

Once dictionaries, indices, masks, fallbacks, and other side information were counted, these alternatives ended up larger than the existing token stream plus HPAC.

---

### 6. Explicit temporal copy / delta coding

Adjacent frames are semantically very similar, making temporal coding look like an obvious win.However, the differences, while sparse, are fragmented, and encoding where those differences occur is not free.

The existing autoregressive model already exploits a lot of the temporal predictability without requiring a separate copy mask or delta representation. Temporal information was still useful, but more as a guide for choosing cheap edits than as a new explicit coding mode.

---

### 7. Shrinking HPAC aggressively

HPAC itself takes a noticeable number of bytes, which makes it an obvious target. Unfortunately, its larger components are also doing most of the useful compression.

Shrinking or heavily quantizing the important spatial predictor reduced the model size, but the token stream grew by more than the model shrank. A few small precision changes were worthwhile, but there was no large easy win here.

---

### 8. Grouping token edits

I also tested whether several nearby semantic edits could be encoded much more cheaply as a group than individually; the effect was modest. The grouped rate was still roughly 90% of the sum of the individual rates, which wasn't enough to justify a new representation. The better strategy was to identify individually cheap edits under the existing coder.

---

### 9. Chasing the PoseNet oracle

There is still a significant free oracle for PoseNet; if arbitrary image changes were free, the pose score could be improved further. However, those changes are high-frequency and very specific to the source frames. Compact low-rank representations captured very little of that signal, while explicitly storing the correction field would cost far more than the score improvement is worth. The important distinction is between an **oracle** and a **compressible oracle**.

---

# Why these results make sense

Eventually, most experiments reduced to straightforward rate-distortion accounting. The final objective is:

$\text{score} = 100 \cdot D_{\text{seg}} + \sqrt{10 \cdot D_{\text{pose}}} + 25R$

Improving only one term is not enough. Near the final operating point, one additional segmentation mismatch is worth roughly **1.27 archive bytes**, or a little over **10 bits**. That gave a useful rule of thumb.

- If an edit fixes one segmentation pixel but costs 18 extra bits, it is probably a bad trade.
- If a renderer approximation saves 500 bytes but creates 500 additional semantic mismatches, it is also a bad trade.
- Similarly, an entropy model that saves 3 KB from the token stream but requires 4 KB of model weights has not actually improved compression.

This is why the safest late improvements were mostly the ones that avoided distortion entirely:

- exact algebraic folding;
- tighter packing;
- removing redundant state;
- better bit allocation;
- discrete improvements using bits that were already present.

---

# Where the remaining difficulty is

By the end, the remaining segmentation errors were heavily concentrated near boundaries, corners, junctions, and thin structures. This makes sense since large, smooth, semantic regions are easy to predict spatially and temporally. The hard part is precise geometry:

- exactly where a boundary falls;
- which way it bends;
- how a narrow object continues;
- which class wins at an ambiguous edge.

That information is high-frequency, source-specific, and expensive to encode. This explains why several experiments showed substantial oracle improvements but poor actual compression results. Knowing which pixels should change is not the same as having a cheap way to communicate those changes.

---

# Final representation

The final codec combines:

- semantic tokens;
- HPAC token prediction and range coding;
- a compact semantic renderer;
- a dedicated pose carrier;
- a small quantized frame latent;
- context warping;
- algebraic renderer folding;
- selective low-bit parameter storage;
- lossless HPAC row packing;
- exact discrete refinement;
- deterministic archive packing.

The final payload is split into five sections:

| Section | Bytes |
|---|---:|
| Models | 60,680 |
| Residual / table | 96 |
| Token stream | 112,181 |
| Warp | 115 |
| Extensions | 140 |

The payload itself is 173,216 bytes. With the deterministic ZIP container, the final archive is:

```text
173,316 bytes
```

The repository includes these packed sections and a small rebuild script.

Running:

```bash
./rebuild.sh
```

reconstructs the archive byte-for-byte.

---

# Result

The final local reference result is:

| Metric | Result |
|---|---:|
| Seg distortion | **0.00015218947** |
| Pose distortion | **1.20175e-6** |
| Archive size | **173,316 bytes** |
| Score | **0.13408959** |

There is still measurable headroom. In particular, further rate-aware token search found additional favorable edits, and both segmentation and pose still have non-zero oracles.

But by this point the remaining gains were getting smaller, more expensive to search for, and harder to encode economically, so I stopped optimizing and froze the result.

---

# Takeaways

The biggest lesson from the challenge was that the right representation depends on what is consuming the reconstruction. The judge is not a human viewer; it's SegNet + PoseNet. That makes the problem less about preserving the source video uniformly and more about identifying which information actually affects those models.

The second lesson was that the nature of useful optimization changes as the codec gets smaller. Early improvements came from better representations and better models, while late improvements came from much less glamorous things:

- exact discrete choices;
- algebraic equivalences;
- parameter precision;
- coding cost;
- storage layout.