# Copyright 2025 Luis M. B. Varona
#
# Licensed under the MIT license <LICENSE or
# http://opensource.org/licenses/MIT>. This file may not be copied, modified, or
# distributed except according to those terms.

from sys import argv

import numpy as np
from Cython.Build import cythonize
from setuptools import Extension, setup


def main():
    argv.extend(["build_ext", "--inplace"])
    setup(
        packages=[],
        ext_modules=cythonize(
            [Extension("src.helpers.utils", sources=["src/helpers/utils.pyx"])],
            compiler_directives={"language_level": "3"},
        ),
        include_dirs=[np.get_include()],
    )


if __name__ == "__main__":
    main()
