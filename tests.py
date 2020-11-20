#!/usr/bin/env python3
from glob import glob
import re
import unittest

from termpub.renderer import Renderer

class RendererTests(unittest.TestCase):

    def setUp(self):
        self.renderer = Renderer()

    def test_files(self):
        for file in glob('render_tests/*.txt'):
            with self.subTest(msg=file):
                self.assertRender(file);

    def assertRender(self, file):
        print(file)
        found_page_break = 0
        input = ''
        output = []
        with open(file) as fh:
            lines = [line.rstrip("\n") for line in fh]
        for line in lines:
            if re.match(r'^$', line):
                found_page_break = 1
                continue
            if found_page_break:
                output += [ line ]
            else:
                input += line + "\n"
        self.assertEqual(self.renderer.render(input)[0],output)
                        

if __name__ == '__main__':
    unittest.main()
