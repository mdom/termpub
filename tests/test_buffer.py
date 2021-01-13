#!/usr/bin/env python3
from glob import glob
import re
import unittest

from termpub.graphemebuffer import Buffer

class BufferTests(unittest.TestCase):

    def test_split(self):
        a = Buffer()
        self.assertEqual(a.graphemes, [])
        a.add('b')
        self.assertEqual(a.graphemes, ["b"])
        a.add('a')
        self.assertEqual(a.graphemes, ["b", "a"])
        self.assertEqual(a.current_grapheme(), "a")
        a.add('\u0308')
        self.assertEqual(a.graphemes, ["b", "a\u0308"])
        self.assertEqual(a.to_string(), "ba\u0308")

        a.move_left()
        a.add('c')
        self.assertEqual(a.to_string(), "bca\u0308")
        a.move_right()
        a.move_right()
        a.add('d')
        self.assertEqual(a.to_string(), "bca\u0308d")

        a.move_left()
        a.delete_backward()
        self.assertEqual(a.to_string(), "bcd")
        a.delete_forward()
        self.assertEqual(a.to_string(), "bc")
        a.add('d')
        a.delete_backward()
        self.assertEqual(a.to_string(), "bc")
        a.delete_forward()
        self.assertEqual(a.to_string(), "bc")
        a.delete_backward()
        a.delete_backward()
        self.assertEqual(a.to_string(), "")

        a.add('cd')
        a.move_left()
        a.add('a')
        a.add('\u0308')
        self.assertEqual(a.to_string(), "ca\u0308d")

        a = Buffer()
        a.add('The quick brown fox jumps over the lazy dog')
        a.index = 10
        slice, index = a.slice(8)
        self.assertEqual(slice, 'k brown ')
        self.assertEqual(index, 2)

        a.move_to_start()
        a.add('"')
        self.assertEqual(a.to_string(),'"The quick brown fox jumps over the lazy dog')

        a.move_to_end()
        a.add('"')
        self.assertEqual(a.to_string(),'"The quick brown fox jumps over the lazy dog"')

        a.move_to_start()
        a.move_right(2)
        a.delete_to_end()
        self.assertEqual(a.to_string(),'"T')

        a.clear()
        self.assertEqual(a.to_string(),'')


if __name__ == '__main__':
    unittest.main()
