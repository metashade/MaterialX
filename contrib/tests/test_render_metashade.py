"""
Render tests for MaterialX materials with Metashade overrides.

This test file runs standard library materials against a MaterialX standard library
where Metashade implementations are loaded first, forcing them to take priority
by document insertion order.
"""
from __future__ import annotations

import os
from pathlib import Path

import pytest
import MaterialX as mx
from test_render import (
    add_additional_test_streams,
    collect_adsk_test_files,
    collect_aswf_test_files,
    RenderEnvironment,
    RenderTestCase,
)

_SOURCE_CODE_NODE_PASSTHRUS = "source_code_node_passthrus"


class _RefPaths:
    """Paths for Metashade reference data.

    ``LIBRARIES`` is always repo-relative (committed reference inputs).
    ``ENV_SUBPATH`` is the environment subpath for render output,
    relative to ``output_root``.
    """
    ROOT = Path("tests") / "metashade_ref"
    LIBRARIES = Path("contrib") / ROOT / "libraries"
    ENV_SUBPATH = ROOT / "renders"


class MetashadeOverrideTestBase:
    """Base class for testing Metashade overrides."""
    SUBDIR = None
    IMAGE_REF_ENV_SUBPATH = None

    @pytest.fixture(scope="class")
    def override_search_path(self, search_path, repo_root):
        """Create a custom search path including standard library source files and overrides."""
        custom_sp = mx.FileSearchPath(search_path.asString())
        
        # Find genglsl directories under the search_path so the shader
        # generator can resolve #include directives for both pbrlib and
        # stdlib source-code nodes (e.g. mx_rotate_vector3.glsl).
        for p_str in search_path.asString().split(os.pathsep):
            p = Path(p_str)
            for lib in ("pbrlib", "stdlib"):
                genglsl = p / "libraries" / lib / "genglsl"
                if genglsl.exists():
                    custom_sp.append(genglsl.as_posix())
                else:
                    genglsl_local = p / lib / "genglsl"
                    if genglsl_local.exists():
                        custom_sp.append(genglsl_local.as_posix())
            
        return custom_sp

    @pytest.fixture(scope="class")
    def override_stdlib(self, request, override_search_path, repo_root):
        """Create a custom stdlib document with Metashade override loaded first."""
        lib = mx.createDocument()
        
        subdir = request.cls.SUBDIR
        assert subdir is not None, (
            "SUBDIR must be defined in the test class "
            "subclassing MetashadeOverrideTestBase"
        )
        
        libraries_dir = repo_root / _RefPaths.LIBRARIES
        override_sp = mx.FileSearchPath(libraries_dir.as_posix())

        # Load generated overrides (nodedef, impl, GLSL, nodegraph)
        mx.loadLibraries([subdir], override_sp, lib)
        override_dir = libraries_dir / subdir
        assert lib.getChildren(), (
            f"loadLibraries loaded nothing from {override_dir}"
        )

        # Expose the override .glsl files to the shader generator
        override_search_path.append(override_dir.as_posix())

        # Load standard libraries second
        library_folders = mx.getDefaultDataLibraryFolders()
        mx.loadLibraries(library_folders, override_search_path, lib)
        return lib
        
    @pytest.fixture(scope="class")
    def override_renderer(
        self, override_stdlib, override_search_path, repo_root,
        mtlx_test_options, cli_options,
    ):
        """Create a custom renderer initialized with the overridden stdlib.

        When ``--no-render`` is active, returns a lightweight
        :class:`ShaderGenWrapper` instead of a full GL renderer.
        """
        if cli_options.no_render:
            from rendertest.mtlxutils.mxrenderer import ShaderGenWrapper
            return ShaderGenWrapper(override_stdlib, override_search_path)

        # IBL paths
        lights_path = repo_root / "resources" / "Lights"
        radiance_path = lights_path / "san_giuseppe_bridge.hdr"
        irradiance_path = (
            lights_path / "irradiance" / "san_giuseppe_bridge.hdr"
        )
        
        # Geometry
        geometry_path = repo_root / "resources" / "Geometry" / "sphere.obj"
        
        # Render size
        width = height = 512
        
        from rendertest.mtlxutils import mxrenderer
        
        renderer = mxrenderer.initializeRenderer(
            override_stdlib,
            override_search_path,
            str(radiance_path),
            str(irradiance_path),
            width,
            height,
            str(geometry_path),
            envSampleCount=mtlx_test_options.env_sample_count,
        )
        
        # Add test geometry streams
        geom_handler = renderer.renderer.getGeometryHandler()
        for mesh in geom_handler.getMeshes():
            add_additional_test_streams(mesh)
            
        return renderer

    @pytest.fixture(scope="class")
    def override_env(
        self, request, override_renderer, override_stdlib,
        override_search_path, cli_options,
    ):
        """Build a :class:`RenderEnvironment` with Metashade overrides.

        In developer mode, render output goes directly into the committed
        baseline directory (``metashade_ref/renders/<subdir>``).
        Review changes with ``git diff``.
        """
        subdir = request.cls.SUBDIR
        assert subdir is not None, (
            "SUBDIR must be defined in the test class "
            "subclassing MetashadeOverrideTestBase"
        )

        return RenderEnvironment(
            renderer=override_renderer,
            data_library=override_stdlib,
            search_path=override_search_path,
            cli_options=cli_options,
            env_subpath=_RefPaths.ENV_SUBPATH / subdir,
            image_ref_env_subpath=request.cls.IMAGE_REF_ENV_SUBPATH,
        )


class TestRenderMetashadePassthru(MetashadeOverrideTestBase):
    """Test rendering with Metashade passthrough overrides.

    Scope matches MaterialXTest's ``_options.mtlx`` render test paths so
    that every material with a C++ baseline is also validated through the
    Metashade override pipeline.
    """
    SUBDIR = _SOURCE_CODE_NODE_PASSTHRUS

    @pytest.mark.parametrize("case", collect_aswf_test_files())
    def test_render(self, case: RenderTestCase, subtests, override_env):
        """Test all renderable elements in a material file using the passthrough override."""
        override_env.run_test(case, subtests)


_SCHLICK_TEST_PATHS = (
    "TestSuite/pbrlib/bsdf/generalized_schlick.mtlx",
    "TestSuite/pbrlib/edf/generalized_schlick_edf.mtlx",
    "TestSuite/pbrlib/surfaceshader/lama/lama_generalized_schlick.mtlx",
    "TestSuite/pbrlib/bsdf/thin_film_bsdf.mtlx",
    "TestSuite/pbrlib/surfaceshader/surface_ops.mtlx",
    "Examples/StandardSurface/standard_surface_default.mtlx",
    "Examples/StandardSurface/standard_surface_gold.mtlx",
    "Examples/StandardSurface/standard_surface_plastic.mtlx",
)


def _get_schlick_test_files():
    """Collect .mtlx files that directly or transitively exercise Schlick BSDF."""
    from test_render import get_repo_root
    materials_root = get_repo_root() / "resources" / "Materials"
    files = []
    for rel in _SCHLICK_TEST_PATHS:
        mtlx_file = materials_root / rel
        if mtlx_file.exists():
            subpath = Path("aswf") / mtlx_file.stem
            case = RenderTestCase(input_path=mtlx_file, output_subpath=subpath)
            files.append(pytest.param(case, id=rel))
    return files


class TestRenderMetashadeBrokenSchlick(MetashadeOverrideTestBase):
    """Test rendering with the Broken Schlick diagnostic override.

    Scoped to materials that directly or transitively exercise
    ``generalized_schlick_bsdf``, so visual diffs are meaningful.
    """
    SUBDIR = "broken_schlick"

    @pytest.mark.parametrize("case", _get_schlick_test_files())
    def test_render(self, case: RenderTestCase, subtests, override_env):
        """Test rendering with Broken Schlick override."""
        override_env.run_test(case, subtests)


_STANDARD_SURFACE_TEST_PATHS = (
    "Examples/StandardSurface/standard_surface_default.mtlx",
    "Examples/StandardSurface/standard_surface_plastic.mtlx",
    "Examples/StandardSurface/standard_surface_gold.mtlx",
    "Examples/StandardSurface/standard_surface_chrome.mtlx",
    "Examples/StandardSurface/standard_surface_greysphere.mtlx",
    "Examples/StandardSurface/standard_surface_thin_film.mtlx",
    "Examples/StandardSurface/standard_surface_glass_tinted.mtlx",
    "Examples/StandardSurface/standard_surface_glass.mtlx",
    "Examples/StandardSurface/standard_surface_metal_brushed.mtlx",
    "Examples/StandardSurface/standard_surface_velvet.mtlx",
    "Examples/StandardSurface/standard_surface_carpaint.mtlx",
    "Examples/StandardSurface/standard_surface_jade.mtlx",
    "Examples/StandardSurface/standard_surface_brass_tiled.mtlx",
    "Examples/StandardSurface/standard_surface_brick_procedural.mtlx",
    "Examples/StandardSurface/standard_surface_chess_set.mtlx",
    "Examples/StandardSurface/standard_surface_copper.mtlx",
    "Examples/StandardSurface/standard_surface_greysphere_calibration.mtlx",
    "Examples/StandardSurface/standard_surface_look_brass_tiled.mtlx",
    "Examples/StandardSurface/standard_surface_look_wood_tiled.mtlx",
    "Examples/StandardSurface/standard_surface_marble_solid.mtlx",
    "Examples/StandardSurface/standard_surface_onyx_hextiled.mtlx",
    "Examples/StandardSurface/standard_surface_wood_tiled.mtlx",
)


def _get_standard_surface_test_files():
    """Collect .mtlx files that exercise Standard Surface (Tier 1)."""
    from test_render import get_repo_root
    materials_root = get_repo_root() / "resources" / "Materials"
    files = []
    for rel in _STANDARD_SURFACE_TEST_PATHS:
        mtlx_file = materials_root / rel
        if mtlx_file.exists():
            subpath = Path("aswf") / mtlx_file.stem
            case = RenderTestCase(input_path=mtlx_file, output_subpath=subpath)
            files.append(pytest.param(case, id=rel))
    return files


class TestRenderMetashadeStandardSurface(MetashadeOverrideTestBase):
    """Test rendering with the Metashade Standard Surface reimplementation.

    Replaces ``ND_standard_surface_surfaceshader`` with the
    Metashade-generated BSDF that is progressively growing towards
    feature-completeness.  ``IMAGE_REF_ENV_SUBPATH`` points at the
    stdlib renders so that each test automatically FLIP-compares
    against the C++ reference.
    """
    SUBDIR = "standard_surface"
    IMAGE_REF_ENV_SUBPATH = Path("renders")

    @pytest.mark.parametrize("case", _get_standard_surface_test_files())
    def test_render(self, case: RenderTestCase, subtests, override_env):
        """Test rendering with Metashade Standard Surface override."""
        override_env.run_test(case, subtests)


# Materials where subsurface is actively used (non-zero constant or
# texture-driven): jade (0.5), marble_solid (0.4), chess_set King/Queen
# (texture-driven subsurface output).
_SUBSURFACE_ACTIVE = frozenset({"jade", "marble_solid", "chess_set"})

_SUBSURFACE_INACTIVE_TEST_PATHS = tuple(
    p for p in _STANDARD_SURFACE_TEST_PATHS
    if not any(name in p.lower() for name in _SUBSURFACE_ACTIVE)
)


def _get_subsurface_inactive_test_files():
    """Collect .mtlx files where subsurface is at default (0)."""
    from test_render import get_repo_root
    materials_root = get_repo_root() / "resources" / "Materials"
    files = []
    for rel in _SUBSURFACE_INACTIVE_TEST_PATHS:
        mtlx_file = materials_root / rel
        if mtlx_file.exists():
            subpath = Path("aswf") / mtlx_file.stem
            case = RenderTestCase(input_path=mtlx_file, output_subpath=subpath)
            files.append(pytest.param(case, id=rel))
    return files


class TestRenderMetashadeStandardSurfacePruned(MetashadeOverrideTestBase):
    """Test rendering with a pruned Standard Surface variant.

    Uses the ``standard_surface_pruned`` override library where inactive
    BSDF lobes are pruned at code-generation time.  Each material is
    rewritten via :meth:`Permutation.prune_material` to target the
    pruned surfaceshader nodedef.  Scoped to materials that keep
    subsurface at its default (0) so the pruned path is functionally
    identical to the full variant.
    FLIP-compares against the stdlib renders.
    """
    SUBDIR = "standard_surface_pruned"
    IMAGE_REF_ENV_SUBPATH = Path("renders")

    @pytest.fixture(scope="class")
    def pruned_permutation(self, override_stdlib):
        """Create a subsurface-pruned Permutation from the override stdlib."""
        from metashade.mtlx.standard_surface import Permutation
        return Permutation(override_stdlib, subsurface=False)

    @pytest.mark.parametrize("case", _get_subsurface_inactive_test_files())
    def test_render(
        self, case: RenderTestCase, subtests, override_env,
        pruned_permutation,
    ):
        """Test rendering with pruned Standard Surface override."""
        doc = mx.createDocument()
        mx.readFromXmlFile(doc, str(case.input_path))

        pruned_doc = pruned_permutation.prune_material(doc)
        assert pruned_doc is not None, (
            "prune_material() returned None for a pruned permutation"
        )

        # Write pruned material next to the rendered images / shader
        # dumps so it is committed as a reviewable test reference.
        # Flatten xi:include so the file is self-contained.
        write_opts = mx.XmlWriteOptions()
        write_opts.writeXIncludeEnable = False
        output_dir = override_env.get_output_path(case)
        output_dir.mkdir(parents=True, exist_ok=True)
        pruned_path = output_dir / case.input_path.name
        mx.writeToXmlFile(pruned_doc, str(pruned_path), write_opts)

        # Ensure textures referenced by the original material resolve
        # when rendering from the output directory.
        override_env.search_path.append(
            str(case.input_path.parent.resolve())
        )

        pruned_case = RenderTestCase(
            input_path=pruned_path,
            output_subpath=case.output_subpath,
        )
        override_env.run_test(pruned_case, subtests)


def _get_adsk_metashade_test_files():
    """Collect adsk materials for Metashade override testing."""
    return collect_adsk_test_files()


class TestRenderMetashadeAdskMaterials(MetashadeOverrideTestBase):
    """Test Autodesk materials with the Metashade Standard Surface override.

    Prism and Protein nodegraphs wrap ``standard_surface``, so they
    exercise the Metashade reimplementation transitively.  Requires
    adsklib alongside the overridden stdlib for node resolution.
    FLIP-compares against the stock ``adsk_env`` renders.
    """
    SUBDIR = "standard_surface"
    IMAGE_REF_ENV_SUBPATH = Path("renders")

    @pytest.fixture(scope="class")
    def override_data_library(self, override_stdlib, adsklib):
        """Combined data library: overridden stdlib + adsklib."""
        lib = mx.createDocument()
        lib.importLibrary(override_stdlib)
        lib.importLibrary(adsklib)
        return lib

    @pytest.fixture(scope="class")
    def override_env(
        self, request, override_renderer, override_data_library,
        override_search_path, cli_options,
    ):
        """RenderEnvironment with Metashade override and adsklib loaded."""
        return RenderEnvironment(
            renderer=override_renderer,
            data_library=override_data_library,
            search_path=override_search_path,
            cli_options=cli_options,
            env_subpath=_RefPaths.ENV_SUBPATH / self.SUBDIR,
            image_ref_env_subpath=self.IMAGE_REF_ENV_SUBPATH,
        )

    @pytest.mark.parametrize("case", _get_adsk_metashade_test_files())
    def test_render(self, case: RenderTestCase, subtests, override_env):
        """Test all renderable elements with Metashade SS override."""
        override_env.run_test(case, subtests)
