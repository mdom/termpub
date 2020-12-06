from setuptools import setup, find_packages

setup(
    author = 'Mario Domgoergen',
    author_email = 'mario@domgoergen.com',
    name = 'termpub',
    license = 'GPL-3.0',
    version = '2020.12.06.1',
    url = 'https://github.com/mdom/termpub',
    packages=["termpub"],
    entry_points = {
        "console_scripts": [
            "termpub=termpub.__main__:main"
        ],
    },
)
