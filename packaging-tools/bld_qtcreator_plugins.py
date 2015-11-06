#!/usr/bin/env python
#############################################################################
##
## Copyright (C) 2013 Digia Plc and/or its subsidiary(-ies).
## Contact: http://www.qt-project.org/legal
##
## This file is part of the release tools of the Qt Toolkit.
##
## $QT_BEGIN_LICENSE:LGPL$
## Commercial License Usage
## Licensees holding valid commercial Qt licenses may use this file in
## accordance with the commercial license agreement provided with the
## Software or, alternatively, in accordance with the terms contained in
## a written agreement between you and Digia.  For licensing terms and
## conditions see http://qt.digia.com/licensing.  For further information
## use the contact form at http://qt.digia.com/contact-us.
##
## GNU Lesser General Public License Usage
## Alternatively, this file may be used under the terms of the GNU Lesser
## General Public License version 2.1 as published by the Free Software
## Foundation and appearing in the file LICENSE.LGPL included in the
## packaging of this file.  Please review the following information to
## ensure the GNU Lesser General Public License version 2.1 requirements
## will be met: http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
##
## In addition, as a special exception, Digia gives you certain additional
## rights.  These rights are described in the Digia Qt LGPL Exception
## version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
##
## GNU General Public License Usage
## Alternatively, this file may be used under the terms of the GNU
## General Public License version 3.0 as published by the Free Software
## Foundation and appearing in the file LICENSE.GPL included in the
## packaging of this file.  Please review the following information to
## ensure the GNU General Public License version 3.0 requirements will be
## met: http://www.gnu.org/copyleft/gpl.html.
##
##
## $QT_END_LICENSE$
##
#############################################################################

# import the print function which is used in python 3.x
from __future__ import print_function

# built in imports
import argparse # commandline argument parser
import collections
import multiprocessing
import os
import sys
from urlparse import urlparse

# own imports
from threadedwork import Task, ThreadedWork
from bld_utils import download, runBuildCommand, runCommand, runInstallCommand, stripVars
import bldinstallercommon

from bld_qtcreator import add_common_commandline_arguments, patch_qt_pri_files, qmake_binary, get_common_environment

def parse_arguments():
    parser = argparse.ArgumentParser(description='Build Qt Creator plugins',
        formatter_class=argparse.RawTextHelpFormatter)
    add_common_commandline_arguments(parser)
    parser.add_argument('--build-path', help='The path to use as a base for all build results',
                        required=True)
    build_group = parser.add_mutually_exclusive_group(required=True)
    build_group.add_argument('--qtc-build-url', help='Path to the Qt Creator build to use')
    build_group.add_argument('--qtc-build', help='Path to the Qt Creator build to use')
    dev_group = parser.add_mutually_exclusive_group(required=True)
    dev_group.add_argument('--qtc-dev-url', help='Path to the Qt Creator dev source to use')
    dev_group.add_argument('--qtc-dev', help='Path to the Qt Creator dev source to use')
    parser.add_argument('--qt-module', help='Qt module package needed for building aside from essentials',
        dest='qt_modules', action='append')
    parser.add_argument('--plugin-search-path', help='Adds search path for plugin dependencies (QTC_PLUGIN_DIRS)',
        dest='plugin_search_paths', action='append')
    parser.add_argument('--add-qmake-argument', help='Adds an argument to the qmake command line',
        dest='additional_qmake_arguments', action='append')
    parser.add_argument('--plugin-path', help='Path to a plugin to build', required=True,
        dest='plugin_paths', action='append')
    parser.add_argument('target_7zfile')
    parser.epilog += ' --build-path /tmp/plugin_build'
    parser.epilog += ' --qtc-build-url http://myserver/path/qtcreator_build.7z'
    parser.epilog += ' --qtc-dev-url http://myserver/path/qtcreator_dev.7z'
    parser.epilog += ' --plugin-path /home/myplugin1 --plugin-path /home/myplugin2'
    parser.epilog += ' /tmp/plugin_build/myplugins.7z'
    caller_arguments = parser.parse_args()
    # normalize arguments
    stripVars(caller_arguments, "\"")
    caller_arguments.build_path = os.path.abspath(caller_arguments.build_path)
    caller_arguments.plugin_paths = [os.path.abspath(path) for path in caller_arguments.plugin_paths]
    caller_arguments.qtc_build = (os.path.abspath(caller_arguments.qtc_build) if caller_arguments.qtc_build
        else os.path.join(caller_arguments.build_path, 'qtc_build'))
    caller_arguments.qtc_dev = (os.path.abspath(caller_arguments.qtc_dev) if caller_arguments.qtc_dev
        else os.path.join(caller_arguments.build_path, 'qtc_dev'))
    return caller_arguments

def get_common_qmake_arguments(paths, caller_arguments):
    qtc_build_tree = paths.qtc_build
    qtc_build_app_bundle = os.path.join(qtc_build_tree, 'Qt Creator.app')
    if bldinstallercommon.is_mac_platform() and os.path.isdir(qtc_build_app_bundle):
        qtc_build_tree = qtc_build_app_bundle
    build_type = 'debug' if caller_arguments.debug else 'release'
    common_qmake_arguments = ['-r', 'CONFIG+={0}'.format(build_type),
                              'IDE_SOURCE_TREE="{0}"'.format(paths.qtc_dev),
                              'IDE_BUILD_TREE="{0}"'.format(qtc_build_tree),
                              'IDE_OUTPUT_PATH="{0}"'.format(paths.target)]
    if caller_arguments.plugin_search_paths:
        common_qmake_arguments.append('QTC_PLUGIN_DIRS={0}'.format(' '.join(caller_arguments.plugin_search_paths)))
    if caller_arguments.additional_qmake_arguments:
        common_qmake_arguments.extend(caller_arguments.additional_qmake_arguments)
    if bldinstallercommon.is_mac_platform(): # work around QTBUG-41238
        common_qmake_arguments.append('QMAKE_MAC_SDK=macosx')
    if sys.platform == 'win32':  # allow app to run on Windows XP
        common_qmake_arguments.append('QMAKE_SUBSYSTEM_SUFFIX=,5.01')
    return common_qmake_arguments

def plugin_build_path(plugin_path, build_path):
    return os.path.join(build_path, 'build-' + os.path.basename(plugin_path))

if __name__ == "__main__":
    bldinstallercommon.init_common_module(os.path.dirname(os.path.realpath(__file__)))
    caller_arguments = parse_arguments()
    (basename, ext) = os.path.splitext(os.path.basename(caller_arguments.target_7zfile))
    Paths = collections.namedtuple('Paths', ['qt5', 'temp', 'qtc_dev', 'qtc_build', 'target'])
    paths = Paths(qt5 = os.path.join(caller_arguments.build_path, basename + '-qt5'),
                  temp = os.path.join(caller_arguments.build_path, basename + '-temp'),
                  qtc_dev = caller_arguments.qtc_dev,
                  qtc_build = caller_arguments.qtc_build,
                  target = os.path.join(caller_arguments.build_path, basename + '-target'))

    if caller_arguments.clean:
        bldinstallercommon.remove_tree(paths.qt5)
        bldinstallercommon.remove_tree(paths.temp)
        if caller_arguments.qtc_dev_url:
            bldinstallercommon.remove_tree(paths.qtc_dev)
        if caller_arguments.qtc_build_url:
            bldinstallercommon.remove_tree(paths.qtc_build)
        bldinstallercommon.remove_tree(paths.target)
        for plugin_path in caller_arguments.plugin_paths:
            bldinstallercommon.remove_tree(plugin_build_path(plugin_path, caller_arguments.build_path))

    download_packages_work = ThreadedWork('Get and extract all needed packages')
    need_to_install_qt = not os.path.exists(paths.qt5)
    if need_to_install_qt:
        modules = ['essentials']
        if caller_arguments.qt_modules:
            modules.extend(caller_arguments.qt_modules)
        download_packages_work.addTaskObject(bldinstallercommon.create_qt_download_task(
            [caller_arguments.qt5_packages_url + '/qt5_' + module + '.7z' for module in modules],
            paths.qt5, paths.temp, caller_arguments))
    if caller_arguments.qtc_build_url and not os.path.exists(paths.qtc_build):
        download_packages_work.addTaskObject(bldinstallercommon.create_download_extract_task(caller_arguments.qtc_build_url,
                                             paths.qtc_build, paths.temp, caller_arguments))
    if caller_arguments.qtc_dev_url and not os.path.exists(paths.qtc_dev):
        download_packages_work.addTaskObject(bldinstallercommon.create_download_extract_task(caller_arguments.qtc_dev_url,
                                             paths.qtc_dev, paths.temp, caller_arguments))
    if download_packages_work.taskNumber != 0:
        download_packages_work.run()
    if need_to_install_qt:
        patch_qt_pri_files(paths.qt5)
        bldinstallercommon.patch_qt(paths.qt5)

    # qmake arguments
    qmake_filepath = qmake_binary(paths.qt5)
    common_qmake_arguments = get_common_qmake_arguments(paths, caller_arguments)

    # environment
    environment = get_common_environment(paths.qt5, caller_arguments)

    # build plugins
    for plugin_path in caller_arguments.plugin_paths:
        build_path = plugin_build_path(plugin_path, caller_arguments.build_path)
        print('------------')
        print('Building plugin "{0}" in "{1}" ...'.format(plugin_path, build_path))
        qmake_command = [qmake_filepath]
        qmake_command.append(plugin_path)
        qmake_command.extend(common_qmake_arguments)
        runCommand(qmake_command, build_path,
            callerArguments = caller_arguments, init_environment = environment)
        runBuildCommand(currentWorkingDirectory = build_path,
            callerArguments = caller_arguments, init_environment = environment)

    # deploy and zip up
    deploy_command = ['python', '-u', os.path.join(paths.qtc_dev, 'scripts', 'packagePlugins.py'),
                      '--qmake_binary', os.path.join(paths.qt5, 'bin', 'qmake')]
    if hasattr(caller_arguments, 'sevenzippath') and caller_arguments.sevenzippath:
        sevenzip_filepath = os.path.join(caller_arguments.sevenzippath,
            '7z.exe' if bldinstallercommon.is_win_platform() else '7z')
        deploy_command.extend(['--7z', sevenzip_filepath])
    deploy_command.extend([paths.target, caller_arguments.target_7zfile])
    runCommand(deploy_command, paths.temp,
        callerArguments = caller_arguments, init_environment = environment)