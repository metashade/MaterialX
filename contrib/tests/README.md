# Test Architecture

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

Determined at **collection time** by the collection function and stored on
`RenderTestCase`. Each collection function knows its own directory
structure and naming convention:

| Collection function | Prefix | Layout | Example |
|---|---|---|---|
| `collect_aswf_test_files()` | `aswf/` | Flat (`<stem>`) | `aswf/standard_surface_default` |
| `collect_adsk_test_files()` | `adsk/` | Hierarchical | `adsk/Examples/Revit/wallpaint` |

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
path logic — those are properties of the collection function.

Environments select which collections to use:

| Environment | Collections | Purpose |
|---|---|---|
| stdlib | `collect_aswf_test_files` | ASWF materials baseline |
| adsk | `collect_adsk_test_files` | Autodesk materials baseline |
| Metashade passthru | `collect_render_test_files` (legacy) | Prove overrides match C++ |
| Metashade broken schlick | explicit file list | Diagnostic override |

## Comparison Modes

### 1. Shader source comparison (RefDiffer)

Compares dumped `.glsl` files against committed baselines within the same
environment. Active in CI mode (when `output_root` diverges from
`repo_root / "contrib"`). In developer mode, `git diff` serves this
purpose.

### 2. Cross-environment image comparison (FLIP)

Compares renders from one environment against another to prove
equivalence. For example, Metashade passthru renders vs stdlib renders.

Since environment subpaths are fixed constants, the comparison is
hardcoded per environment — no CLI flag needed. The relationship is a
property of the environment definition.

Requires separate pytest runs: the baseline environment must render first,
then the comparison environment renders and FLIPs against it.

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
