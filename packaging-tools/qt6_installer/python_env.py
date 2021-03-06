#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#############################################################################
##
## Copyright (C) 2020 The Qt Company Ltd.
## Contact: https://www.qt.io/licensing/
##
## This file is part of the release tools of the Qt Toolkit.
##
## $QT_BEGIN_LICENSE:GPL-EXCEPT$
## Commercial License Usage
## Licensees holding valid commercial Qt licenses may use this file in
## accordance with the commercial license agreement provided with the
## Software or, alternatively, in accordance with the terms contained in
## a written agreement between you and The Qt Company. For licensing terms
## and conditions see https://www.qt.io/terms-conditions. For further
## information use the contact form at https://www.qt.io/contact-us.
##
## GNU General Public License Usage
## Alternatively, this file may be used under the terms of the GNU
## General Public License version 3 as published by the Free Software
## Foundation with exceptions as appearing in the file LICENSE.GPL3-EXCEPT
## included in the packaging of this file. Please review the following
## information to ensure the GNU General Public License requirements will
## be met: https://www.gnu.org/licenses/gpl-3.0.html.
##
## $QT_END_LICENSE$
##
#############################################################################

import os
import sys
import asyncio
import argparse
import platform
import subprocess
from typing import Dict, Tuple
from bld_python import build_python
from logging_util import init_logger
from runner import exec_cmd


log = init_logger(__name__, debug_mode=False)


def get_env(pythonInstallation: str) -> Dict[str, str]:
    env = os.environ.copy()
    system = platform.system().lower()
    libDir = os.path.join(pythonInstallation, "lib")
    binDir = os.path.join(pythonInstallation, "bin")
    if "windows" in system:
        env["LIB_PATH"] = libDir
        env["PATH"] = binDir + ";" + env.get("PATH", "")
    elif "darwin" in system:
        env["DYLD_LIBRARY_PATH"] = libDir
        env["PATH"] = binDir + ":" + env.get("PATH", "")
    else:
        env["LD_LIBRARY_PATH"] = libDir
        env["PATH"] = binDir + ":" + env.get("PATH", "")
    return env


def locate_venv(pythonDir: str, env: Dict[str, str]) -> str:
    pipenv = os.path.join(pythonDir, "bin", "pipenv")
    assert os.path.isfile(pipenv), "The 'pipenv' executable did not exist: {0}".format(pipenv)
    output = subprocess.check_output(pipenv + " --venv", shell=True, env=env).decode("utf-8")
    return output.splitlines()[0].strip()


async def create_venv(pythonSrc: str) -> Tuple[str, Dict[str, str]]:
    log.info("Creating Python virtual env..")
    prefix = os.path.join(os.path.expanduser("~"), "_python_bld")
    installDir = await build_python(pythonSrc, prefix)
    env = get_env(prefix)
    pip3 = os.path.join(installDir, "bin", "pip3")
    assert os.path.isfile(pip3), "The 'pip3' executable did not exist: {0}".format(pip3)
    log.info("Installing pipenv..")
    cmd = [pip3, 'install', 'pipenv']
    await exec_cmd(cmd=cmd, timeout=60 * 15, env=env)  # give it 15 mins
    pipenv = os.path.join(installDir, "bin", "pipenv")
    assert os.path.isfile(pipenv), "The 'pipenv' executable did not exist: {0}".format(pipenv)
    cmd = [pipenv, 'install']
    log.info("Installing pipenv requirements into: %s", prefix)
    await exec_cmd(cmd=cmd, timeout=60 * 30, env=env)  # give it 30 mins
    log.info("Virtual env created into: %s", locate_venv(installDir, env))
    return (installDir, env)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="Create Python virtual env")
    parser.add_argument("--python-src", dest="python_src", type=str, default=os.getenv("PYTHON_SRC"), help="Path to local checkout or .zip/.7z/.tar.gz")
    args = parser.parse_args(sys.argv[1:])
    loop = asyncio.get_event_loop()
    loop.run_until_complete(create_venv(args.python_src))
