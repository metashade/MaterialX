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
        
        # Find pbrlib/genglsl under the search_path directories to match standard library include resolution.
        for p_str in search_path.asString().split(os.pathsep):
            p = Path(p_str)
            pbrlib_genglsl = p / "libraries" / "pbrlib" / "genglsl"
            if pbrlib_genglsl.exists():
                custom_sp.append(pbrlib_genglsl.as_posix())
                break
            pbrlib_genglsl_local = p / "pbrlib" / "genglsl"
            if pbrlib_genglsl_local.exists():
                custom_sp.append(pbrlib_genglsl_local.as_posix())
                break
            
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
    """Test rendering with the Metashade Standard Surface override.

    Replaces the entire ``ND_standard_surface_surfaceshader`` implementation
    with a Metashade-generated diffuse + specular shader (Oren-Nayar +
    dielectric BSDF layering).  Scoped to Tier 1 Standard Surface assets
    where visual comparison against the C++ nodegraph baseline is meaningful.

    ``IMAGE_REF_ENV_SUBPATH`` points at the stdlib renders so that each
    test automatically compares its rendered image against the C++
    reference.
    """
    SUBDIR = "standard_surface"
    IMAGE_REF_ENV_SUBPATH = Path("renders")

    @pytest.mark.parametrize("mtlx_file", _get_standard_surface_test_files())
    def test_render_file(self, mtlx_file: Path, subtests, override_env):
        """Test rendering with Metashade Standard Surface override."""
        override_env.run_test(mtlx_file, subtests)
