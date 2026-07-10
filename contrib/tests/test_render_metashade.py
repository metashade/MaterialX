"""
Render tests for MaterialX materials with Metashade overrides.

This test file runs standard library materials against a MaterialX standard library
where Metashade implementations are loaded first, forcing them to take priority
by document insertion order.
"""
from __future__ import annotations

import os
from dataclasses import replace
from pathlib import Path

import pytest
import MaterialX as mx
from test_render import (
    add_additional_test_streams,
    collect_render_test_files,
    PytestOptions,
    RenderEnvironment,
)

_SOURCE_CODE_NODE_PASSTHRUS = "source_code_node_passthrus"


class _RefPaths:
    """Repo-relative paths for Metashade reference data."""
    ROOT = Path("contrib") / "tests" / "metashade_ref"
    LIBRARIES = ROOT / "libraries"
    RENDERS = ROOT / "renders"


class MetashadeOverrideTestBase:
    """Base class for testing Metashade overrides."""
    OVERRIDE_SUBDIR = None
    OUTPUT_SUBDIR = None

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
        
        subdir = request.cls.OVERRIDE_SUBDIR
        assert subdir is not None, (
            "OVERRIDE_SUBDIR must be defined in the test class "
            "subclassing MetashadeOverrideTestBase"
        )
        
        libraries_dir = repo_root / _RefPaths.LIBRARIES
        override_sp = mx.FileSearchPath(libraries_dir.as_posix())

        # Load Metashade overrides first so they take priority by insertion order
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
        mtlx_test_options,
    ):
        """Create a custom renderer initialized with the overridden stdlib."""
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
        override_search_path, repo_root, pytest_options,
    ):
        """Build a :class:`RenderEnvironment` with Metashade overrides."""
        output_subdir = request.cls.OUTPUT_SUBDIR
        assert output_subdir is not None, (
            "OUTPUT_SUBDIR must be defined in the test class "
            "subclassing MetashadeOverrideTestBase"
        )
        
        path = pytest_options.output_dir / "metashade" / output_subdir
        path.mkdir(parents=True, exist_ok=True)
        
        renders_dir = repo_root / _RefPaths.RENDERS / output_subdir

        override_options = replace(
            pytest_options,
            output_dir=path,
            shader_baseline_dir=renders_dir,
        )

        return RenderEnvironment(
            renderer=override_renderer,
            data_library=override_stdlib,
            search_path=override_search_path,
            options=override_options,
        )


class TestRenderMetashadePassthru(MetashadeOverrideTestBase):
    """Test rendering with Metashade passthrough overrides.

    Scope matches MaterialXTest's ``_options.mtlx`` render test paths so
    that every material with a C++ baseline is also validated through the
    Metashade override pipeline.
    """
    OVERRIDE_SUBDIR = _SOURCE_CODE_NODE_PASSTHRUS
    OUTPUT_SUBDIR = _SOURCE_CODE_NODE_PASSTHRUS

    @pytest.mark.parametrize("mtlx_file", collect_render_test_files())
    def test_render_file(self, mtlx_file: Path, subtests, override_env):
        """Test all renderable elements in a material file using the passthrough override."""
        override_env.run_test(mtlx_file, subtests)


class TestRenderMetashadeBrokenSchlick(MetashadeOverrideTestBase):
    """Test rendering with the Broken Schlick diagnostic override.

    Uses the same ``_options.mtlx``-driven scope.  Materials that use
    ``generalized_schlick_bsdf`` will show visual diffs; others render
    identically to the baseline.
    """
    OVERRIDE_SUBDIR = "broken_schlick"
    OUTPUT_SUBDIR = "broken_schlick"

    @pytest.mark.parametrize("mtlx_file", collect_render_test_files())
    def test_render_file(self, mtlx_file: Path, subtests, override_env):
        """Test rendering with Broken Schlick override."""
        override_env.run_test(mtlx_file, subtests)
