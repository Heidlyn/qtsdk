#!/usr/bin/env python
#############################################################################
##
## Copyright (C) 2014 Digia Plc and/or its subsidiary(-ies).
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

import glob
import os
import shutil
import subprocess
import urlparse

import bld_utils
import bldinstallercommon
import environmentfrombatchfile

def get_clang(base_path, llvm_revision, clang_revision):
    bld_utils.runCommand(['git', '-c', 'http.postBuffer=524288000', 'clone', 'https://github.com/llvm-mirror/llvm'], base_path)
    bld_utils.runCommand(['git', 'checkout', llvm_revision], os.path.join(base_path, 'llvm'))
    bld_utils.runCommand(['git', '-c', 'http.postBuffer=524288000', 'clone', 'https://github.com/llvm-mirror/clang'], os.path.join(base_path, 'llvm', 'tools'))
    bld_utils.runCommand(['git', 'checkout', clang_revision], os.path.join(base_path, 'llvm', 'tools', 'clang'))

def get_profile_data(profile_data_dir, profile_data_url, generate_instrumented):
    if generate_instrumented:
        return profile_data_dir

    if profile_data_url:
        if os.path.exists(profile_data_dir):
            shutil.rmtree(profile_data_dir)
        compressed_file_name = os.path.basename(urlparse.urlsplit(profile_data_url).path)
        destination_path = os.path.join(profile_data_dir, compressed_file_name)

        bld_utils.download(profile_data_url, destination_path)
        bldinstallercommon.extract_file(destination_path, profile_data_dir)

        return profile_data_dir

    return None

def apply_patch(src_path, patch_filepath):
    print('Applying patch: "' + patch_filepath + '" in "' + src_path + '"')
    with open(patch_filepath, 'r') as f:
        subprocess.check_call(['patch', '-p1'], stdin=f, cwd=src_path)

def apply_patches(src_path, patch_filepaths):
    for patch in patch_filepaths:
        apply_patch(src_path, patch)

def is_msvc_toolchain(toolchain):
    return 'msvc' in toolchain

def is_mingw_toolchain(toolchain):
    return 'mingw' in toolchain

def cmake_generator(toolchain):
    if bldinstallercommon.is_win_platform():
        return 'MinGW Makefiles' if is_mingw_toolchain(toolchain) else 'NMake Makefiles JOM'
    else:
        return 'Unix Makefiles'

def profile_data_flags(toolchain, profile_data_dir, generate_instrumented):
    if profile_data_dir and is_mingw_toolchain(toolchain):
        profile_flag = '-fprofile-generate' if generate_instrumented else '-fprofile-use'
        compiler_flags = profile_flag + '=' + profile_data_dir
        linker_flags = compiler_flags + ' -static-libgcc -static-libstdc++ -static'
        return [
            '-DCMAKE_C_FLAGS=' + compiler_flags,
            '-DCMAKE_CXX_FLAGS=' + compiler_flags,
            '-DCMAKE_SHARED_LINKER_FLAGS=' + linker_flags,
            '-DCMAKE_EXE_LINKER_FLAGS=' + linker_flags,
        ]

    return []

def bitness_flags(bitness):
    if bitness == 32 and bldinstallercommon.is_linux_platform():
        return ['-DLIBXML2_LIBRARIES=/usr/lib/libxml2.so', '-DLLVM_BUILD_32_BITS=ON']
    return []

def rtti_flags(toolchain):
    if is_mingw_toolchain(toolchain):
        return ['-DLLVM_ENABLE_RTTI:BOOL=OFF']
    return ['-DLLVM_ENABLE_RTTI:BOOL=ON']

def make_targets(toolchain):
    if is_mingw_toolchain(toolchain):
        # The mingw build is only used for generation of an optimized libclang.dll.
        return ['libclang']
    return []

def make_command(toolchain):
    if bldinstallercommon.is_win_platform():
        command = ['mingw32-make'] if is_mingw_toolchain(toolchain) else ['jom']
    else:
        command = ['make']

    return command + make_targets(toolchain)

def install_targets(toolchain):
    if is_mingw_toolchain(toolchain):
        # The mingw build is only used for generation of an optimized libclang.dll.
        # Include the necessary headers for two reasons
        #  1) The package can be used right way as LLVM_INSTALL_DIR.
        #  2) Avoid training with manually provided and possible wrong versions
        #     of the headers.
        return [
            'install-libclang',
            'install-libclang-headers',
            'install-clang-headers',
            'install-llvm-config',
        ]
    return ['install']

def install_command(toolchain):
    if bldinstallercommon.is_win_platform():
        command = ['mingw32-make'] if is_mingw_toolchain(toolchain) else ["nmake"]
    else:
        command = ["make", "-j1"]

    return command + install_targets(toolchain)

def cmake_command(toolchain, src_path, build_path, install_path, profile_data_dir, generate_instrumented, bitness, build_type):
    command = ['cmake',
               '-DCMAKE_INSTALL_PREFIX=' + install_path,
               '-G',
               cmake_generator(toolchain),
               '-DCMAKE_BUILD_TYPE=' + build_type]
    command.extend(bitness_flags(bitness))
    command.extend(rtti_flags(toolchain))
    command.extend(profile_data_flags(toolchain, profile_data_dir, generate_instrumented))
    command.append(src_path)

    return command

def build_clang(toolchain, src_path, build_path, install_path, profile_data_path, generate_instrumented, bitness=64, environment=None, build_type='Release'):
    if build_path and not os.path.lexists(build_path):
        os.makedirs(build_path)

    cmake_cmd = cmake_command(toolchain, src_path, build_path, install_path, profile_data_path, generate_instrumented, bitness, build_type)

    bldinstallercommon.do_execute_sub_process(cmake_cmd, build_path, extra_env=environment)
    bldinstallercommon.do_execute_sub_process(make_command(toolchain), build_path, extra_env=environment)
    bldinstallercommon.do_execute_sub_process(install_command(toolchain), build_path, extra_env=environment)

def package_clang(install_path, result_file_path):
    (basepath, dirname) = os.path.split(install_path)
    zip_command = ['7z', 'a', result_file_path, dirname]
    bld_utils.runCommand(zip_command, basepath)

def upload_clang(file_path, remote_path):
    (path, filename) = os.path.split(file_path)
    scp_bin = '%SCP%' if bldinstallercommon.is_win_platform() else 'scp'
    scp_command = [scp_bin, filename, remote_path]
    bld_utils.runCommand(scp_command, path)

def paths_with_sh_exe_removed(path_value):
    items = path_value.split(os.pathsep)
    items = [i for i in items if not os.path.exists(os.path.join(i, 'sh.exe'))]
    return os.pathsep.join(items)

def profile_data(toolchain):
    if bldinstallercommon.is_win_platform() and is_mingw_toolchain(toolchain):
        return os.getenv('PROFILE_DATA_URL')

def build_environment(toolchain, bitness):
    if bldinstallercommon.is_win_platform():
        if is_mingw_toolchain(toolchain):
            environment = dict(os.environ)
            # cmake says "For MinGW make to work correctly sh.exe must NOT be in your path."
            environment['PATH'] = paths_with_sh_exe_removed(environment['PATH'])
            return environment
        else:
            program_files = os.path.join('C:', '/Program Files (x86)')
            if not os.path.exists(program_files):
                program_files = os.path.join('C:', '/Program Files')
            vcvarsall = os.path.join(program_files, 'Microsoft Visual Studio ' + os.environ['MSVC_VERSION'], 'VC', 'vcvarsall.bat')
            arg = 'amd64' if bitness == 64 else 'x86'
            return environmentfrombatchfile.get(vcvarsall, arguments=arg)
    else:
        return None # == process environment

def main():
    bldinstallercommon.init_common_module(os.path.dirname(os.path.realpath(__file__)))
    base_path = os.path.join(os.environ['PKG_NODE_ROOT'])
    branch = os.environ['CLANG_BRANCH']
    src_path = os.path.join(base_path, 'llvm')
    build_path = os.path.join(base_path, 'build')
    install_path = os.path.join(base_path, 'libclang')
    bitness = 64 if '64' in os.environ['cfg'] else 32
    toolchain = os.environ['cfg'].split('-')[1].lower()
    environment = build_environment(toolchain, bitness)
    profile_data_url = profile_data(toolchain)
    profile_data_path = os.path.join(build_path, 'profile_data')
    generate_instrumented = os.environ.get('GENERATE_INSTRUMENTED_BINARIES') == '1'
    instrumented_tag = '-instrumented' if generate_instrumented else ''
    result_file_path = os.path.join(base_path, 'libclang-' + branch + '-' + os.environ['CLANG_PLATFORM'] + instrumented_tag + '.7z')
    remote_path = (os.environ['PACKAGE_STORAGE_SERVER_USER'] + '@' + os.environ['PACKAGE_STORAGE_SERVER'] + ':'
                   + os.environ['PACKAGE_STORAGE_SERVER_BASE_DIR'] + '/' + os.environ['CLANG_UPLOAD_SERVER_PATH'])

    get_clang(base_path, os.environ['LLVM_REVISION'], os.environ['CLANG_REVISION'])
    profile_data_path = get_profile_data(profile_data_path, profile_data_url, generate_instrumented)
    patch_src_path = os.environ.get('CLANG_PATCHES')
    if patch_src_path:
        if not os.path.isabs(patch_src_path):
            patch_src_path = os.path.join(base_path, patch_src_path)
        if not os.path.exists(patch_src_path):
            raise IOError, 'CLANG_PATCHES is set, but directory ' + patch_src_path + ' does not exist, aborting.'
        print 'CLANG_PATCHES: Applying patches from ' + patch_src_path
        apply_patches(src_path, sorted(glob.glob(os.path.join(patch_src_path, '*'))))
    else
        print 'CLANG_PATCHES: Not set, skipping.'
    build_clang(toolchain, src_path, build_path, install_path, profile_data_path, generate_instrumented, bitness, environment, build_type='Release')
    package_clang(install_path, result_file_path)
    upload_clang(result_file_path, remote_path)

if __name__ == "__main__":
    main()
