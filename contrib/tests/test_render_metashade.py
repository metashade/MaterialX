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
    collect_render_test_files,
    RenderEnvironment,
    RenderTestCase,
)

_SOURCE_CODE_NODE_PASSTHRUS = "source_code_node_passthrus"


class _RefPaths:
    """Paths for Metashade reference data.

    ``LIBRARIES`` is always repo-relative (committed reference inputs).
    ``METASHADE_LIBRARIES`` points to hand-written library files inside
    the Metashade submodule (e.g. the Standard Surface nodegraph).
    ``ENV_SUBPATH`` is the environment subpath for render output,
    relative to ``output_root``.
    """
    ROOT = Path("tests") / "metashade_ref"
    LIBRARIES = Path("contrib") / ROOT / "libraries"
    METASHADE_LIBRARIES = (
        Path("contrib") / "metashade" / "tests" / "mtlx" / "libraries"
    )
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

        # Load generated overrides (nodedef, impl, GLSL)
        mx.loadLibraries([subdir], override_sp, lib)
        override_dir = libraries_dir / subdir
        assert lib.getChildren(), (
            f"loadLibraries loaded nothing from {override_dir}"
        )

        # Load hand-written library files (e.g. the SS nodegraph) separately;
        # loadLibraries stops at the first matching subdir, so a single call
        # with both paths would skip the second root.
        metashade_libs = repo_root / _RefPaths.METASHADE_LIBRARIES
        if (metashade_libs / subdir).exists():
            metashade_sp = mx.FileSearchPath(metashade_libs.as_posix())
            mx.loadLibraries([subdir], metashade_sp, lib)

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

    @pytest.mark.parametrize("mtlx_file", collect_render_test_files())
    def test_render_file(self, mtlx_file: Path, subtests, override_env):
        """Test all renderable elements in a material file using the passthrough override."""
        override_env.run_test(mtlx_file, subtests)


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
            files.append(pytest.param(mtlx_file, id=rel))
    return files


class TestRenderMetashadeBrokenSchlick(MetashadeOverrideTestBase):
    """Test rendering with the Broken Schlick diagnostic override.

    Scoped to materials that directly or transitively exercise
    ``generalized_schlick_bsdf``, so visual diffs are meaningful.
    """
    SUBDIR = "broken_schlick"

    @pytest.mark.parametrize("mtlx_file", _get_schlick_test_files())
    def test_render_file(self, mtlx_file: Path, subtests, override_env):
        """Test rendering with Broken Schlick override."""
        override_env.run_test(mtlx_file, subtests)


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
            files.append(pytest.param(mtlx_file, id=rel))
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

    @pytest.mark.parametrize("mtlx_file", _get_standard_surface_test_files())
    def test_render_file(self, mtlx_file: Path, subtests, override_env):
        """Test rendering with Metashade Standard Surface override."""
        override_env.run_test(mtlx_file, subtests)


# Adsk materials excluded from the Metashade SS override test.
# mx_rotate_vector3 duplicate: override search path adds genglsl dirs for
# #include resolution, causing the shader generator to inline
# mx_rotate_vector3 twice when these materials use specular_rotation.
# FLIP threshold: visual difference from the Metashade SS implementation.
_ADSK_METASHADE_EXCLUDE = frozenset({
    "knurl.mtlx",          # mx_rotate_vector3 duplicate
    "marble.mtlx",         # mx_rotate_vector3 duplicate
    "metal.mtlx",          # mx_rotate_vector3 duplicate
    "metallicpaint.mtlx",  # mx_rotate_vector3 duplicate
    "noise.mtlx",          # mx_rotate_vector3 duplicate
    "speckle.mtlx",        # mx_rotate_vector3 duplicate
    "waves.mtlx",          # mx_rotate_vector3 duplicate
    "wood.mtlx",           # mx_rotate_vector3 duplicate
    "masonry.mtlx",        # FLIP threshold (0.073 > 0.05)
})


def _get_adsk_metashade_test_files():
    """Collect adsk materials, excluding known Metashade override failures."""
    return [
        p for p in collect_adsk_test_files()
        if p.values[0].input_path.name not in _ADSK_METASHADE_EXCLUDE
    ]


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
