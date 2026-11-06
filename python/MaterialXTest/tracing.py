#!/usr/bin/env python
'''
Unit tests for MaterialXTrace in MaterialX Python.
'''

import os, tempfile, unittest

import MaterialX as mx
import MaterialX.PyMaterialXGenShader as mx_gen_shader
import MaterialX.PyMaterialXGenGlsl as mx_gen_glsl

try:
    import MaterialX.PyMaterialXTrace as mx_trace
except ImportError:
    mx_trace = None

@unittest.skipIf(mx_trace is None, "PyMaterialXTrace requires Perfetto tracing and shared libraries")
class TestTracing(unittest.TestCase):
    def test_PythonAndCppEvents(self):
        doc = mx.createDocument()
        searchPath = mx.getDefaultDataSearchPath()
        mx.loadLibraries(mx.getDefaultDataLibraryFolders(), searchPath, doc)
        node = doc.addNode("standard_surface", "SR_trace", "surfaceshader")

        generator = mx_gen_glsl.GlslShaderGenerator.create()
        context = mx_gen_shader.GenContext(generator)
        context.registerSourceCodeSearchPath(searchPath)

        pythonEventName = "python_trace_test_scope"
        cppEventName = "cpp_trace_test_shader"

        with tempfile.TemporaryDirectory() as tempDir:
            tracePath = os.path.join(tempDir, "test.perfetto-trace")
            dispatcher = mx_trace.Dispatcher.getInstance()
            dispatcher.setPerfettoSink(tracePath)
            self.assertTrue(dispatcher.isEnabled())
            try:
                with mx_trace.Scope(mx_trace.Category.ShaderGen, pythonEventName):
                    shader = generator.generate(cppEventName, node, context)
                    self.assertIsNotNone(shader)
            finally:
                dispatcher.shutdownSink()
            self.assertFalse(dispatcher.isEnabled())

            with open(tracePath, "rb") as traceFile:
                trace = traceFile.read()

        # Event names are stored in the trace as plain strings.
        self.assertIn(pythonEventName.encode(), trace)
        self.assertIn(cppEventName.encode(), trace)

if __name__ == '__main__':
    unittest.main()
