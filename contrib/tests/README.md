# MaterialX Contrib Test Framework

Pytest-based render and shader-generation tests for MaterialX contrib materials,
built on top of the `rendertest` utilities from Bernard Kwok's
[MaterialX_Learn](https://github.com/kwokcb/MaterialX_Learn).

## Prerequisites

- MaterialX built with Python bindings (`MATERIALX_BUILD_PYTHON=ON`)
- Render support enabled (`MATERIALX_BUILD_RENDER=ON`,
  `MATERIALX_BUILD_GEN_GLSL=ON`)
- `PYTHONPATH` configured to find `MaterialX` and `MaterialX.PyMaterialX*`
  modules
- Install test dependencies:

```bash
pip install -e ".[test]"   # from contrib/tests/
```

## Quick Start

From the `contrib/tests` directory:

```bash
pytest test_render.py -v                # all ASWF materials
pytest test_render.py -k "brass" -v     # single material by keyword
pytest test_render.py --no-render -v    # shader generation only (no GPU)

pytest test_render_metashade.py -v      # Metashade override tests
```

## Output Path Model

All test output follows a three-layer path structure:

```
output_root / env_subpath / output_subpath / <element>.png
```

### Layer 1: Output Root (`output_root`)

The top-level directory for all test output. Configured via:

1. `outputDirectory` in `_options.mtlx` (shared with C++ MaterialXTest)
2. `--output-dir` CLI option (takes precedence)
3. Default: `contrib/` (repo-relative)

In **developer mode** (default), the output root points into the repo so
renders land in committed directories. Review changes with `git diff` and
commit to update baselines.

In **CI mode**, `--output-dir` redirects output to a temp directory.
Committed baselines remain at `repo_root / "contrib" / ...` and are never
affected by the output root.

### Layer 2: Environment Subpath (`env_subpath`)

A fixed relative path owned by each `RenderEnvironment`. This is a
constant — never configurable, never overridden. It defines the
environment's identity in the output tree.

| Environment | `env_subpath` |
|---|---|
| stdlib / adsk (default) | `renders/` |
| Metashade passthru | `tests/metashade_ref/renders/source_code_node_passthrus/` |
| Metashade broken schlick | `tests/metashade_ref/renders/broken_schlick/` |
| Metashade standard surface | `tests/metashade_ref/renders/standard_surface/` |

Environments that test different asset sources (ASWF vs Autodesk) share
the same `env_subpath`. The asset source distinction lives in layer 3.

### Layer 3: Output Subpath (`output_subpath`)

Determined at **collection time** and stored on `RenderTestCase`.
Each asset source has its own directory structure and naming convention:

| Asset source | Prefix | Layout | Example |
|---|---|---|---|
| ASWF materials | `aswf/` | Flat (`<stem>`) | `aswf/standard_surface_default` |
| Autodesk materials | `adsk/` | Hierarchical | `adsk/Examples/Revit/wallpaint` |

Uniqueness is enforced at insertion time — if two files from the same
collection produce the same `output_subpath`, a `ValueError` is raised
immediately.

### Full path examples

Developer mode (`output_root = contrib/`):

```
contrib/renders/aswf/standard_surface_default/Default_glsl.png
contrib/renders/adsk/Examples/Revit/wallpaint/M_legacy_wallpaint_glsl.png
contrib/tests/metashade_ref/renders/source_code_node_passthrus/aswf/standard_surface_default/Default_glsl.png
```

CI mode (`output_root = /tmp/ci_run/`):

```
/tmp/ci_run/renders/aswf/standard_surface_default/Default_glsl.png
/tmp/ci_run/tests/metashade_ref/renders/broken_schlick/aswf/generalized_schlick/Default_glsl.png
```

## Reference Inputs vs Outputs

Reference inputs (committed data read by tests) are always repo-relative
and never governed by `output_root`:

- **Metashade override libraries**: `repo_root / contrib/tests/metashade_ref/libraries/<subdir>/`
- **Standard libraries**: resolved via `mx.getDefaultDataSearchPath()`

Only **outputs** (renders, shader dumps) go under `output_root`.

## Environments

A `RenderEnvironment` bundles a renderer, data library, search path, and
`env_subpath`. It does **not** own a layout strategy or asset-specific
path logic — those are properties of the test collection.

| Environment | Scope | Purpose |
|---|---|---|
| stdlib | All ASWF materials | ASWF materials baseline |
| adsk | All Autodesk materials | Autodesk materials baseline |
| Metashade passthru | All ASWF materials | Prove overrides match C++ |
| Metashade broken schlick | Schlick-related subset | Diagnostic override |
| Metashade standard surface | Standard Surface subset | SS reimplementation, FLIP vs stdlib |

## Comparison Modes

### 1. Shader source comparison (RefDiffer)

Compares dumped `.glsl` files against committed baselines within the same
environment. Active in CI mode (when `output_root` diverges from
`repo_root / "contrib"`). In developer mode, `git diff` serves this
purpose.

### 2. Cross-environment image comparison (FLIP)

Compares renders from one environment against a **reference
environment** using [NVIDIA FLIP](https://github.com/NVlabs/flip), a
perceptual image difference metric.

Each `RenderEnvironment` can declare an `image_ref_env_subpath` — the
`env_subpath` of the environment whose renders serve as the reference.
When set, every rendered image is automatically FLIP-compared after
rendering.  The relationship is a property of the environment definition
(no CLI flag needed).

| Environment | `image_ref_env_subpath` | Compares against |
|---|---|---|
| Metashade standard surface | `renders/` | stdlib C++ renders |
| All others | *(none)* | *(no image comparison)* |

On failure, the assertion reports mean and max FLIP error, and saves a
magma heatmap (`*_diff.png`) next to the rendered image.  When
generating an HTML report (`--html`), failed subtests include
side-by-side thumbnails of the reference image, rendered image, and
FLIP heatmap.

The `--flip-threshold` CLI option (default `0.05`) controls the mean
FLIP error threshold.

**Important:** the reference environment must render first.  If
reference images are missing, the comparison is skipped with a message.
In practice this means running `test_render.py` (stdlib) before
`test_render_metashade.py`.

## CLI Options

| Option | Default | Purpose |
|---|---|---|
| `--output-dir` | `contrib/` | Output root directory |
| `--no-render` | off | Skip GPU rendering (shader generation only) |
| `--flip-threshold` | `0.05` | Mean FLIP error threshold |

## CI Workflow

```
pytest contrib/tests/test_render.py --output-dir /tmp/ci            # 1
cd contrib/metashade && pytest tests/                                # 2
pytest contrib/tests/test_render_metashade.py --output-dir /tmp/ci   # 3
```

1. **Baseline renders** — render stdlib + adsk materials.  Produces
   the reference images that step 3 compares against.
2. **Generate Metashade implementations** — the Metashade repo's own
   tests produce the ``.mtlx`` and ``.glsl`` library inputs under
   ``metashade_ref/libraries/`` consumed by step 3.
3. **Metashade overrides** — render with Metashade overrides and
   FLIP-compare against stdlib renders from step 1.

Both steps 1 and 3 automatically run **RefDiffer** (shader source
comparison against committed ``.glsl`` baselines) whenever
``--output-dir`` is set, because the output tree diverges from the
committed tree.

If CI lacks a GPU, pass ``--no-render`` to skip GPU rendering while
still generating shaders and running RefDiffer.
