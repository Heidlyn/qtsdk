/****************************************************************************
**
** Copyright (C) 2017 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the release tools of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:GPL-EXCEPT$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3 as published by the Free Software
** Foundation with exceptions as appearing in the file LICENSE.GPL3-EXCEPT
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/

// constructor
function Component()
{
    // Determine if this is a online snapshot build
    var snapshotBuild = false;
    var isSnapshotStr = "%ONLINE_SNAPSHOT_BUILD%";
    if (['true', 'yes', '1'].indexOf(isSnapshotStr) >= 0)
        snapshotBuild = true;

    if (snapshotBuild) {
        // Add automatic dependency for preview component
        var autoDependency = component.value("AutoDependOn");
        var dependencyStr = "preview.qt.qt5.511.gcc_64";
        if (autoDependency) {
            component.setValue("AutoDependOn", autoDependency+","+dependencyStr)
        }
        else {
            component.setValue("AutoDependOn", dependencyStr)
        }
    }
}

Component.prototype.beginInstallation = function()
{
    installer.setValue(component.name + "_qtpath", "@TargetDir@" + "%TARGET_INSTALL_DIR%");
}

Component.prototype.createOperations = function()
{
    component.createOperations();

    if (installer.value("os") == "x11") {
        var qtPath = "@TargetDir@" + "%TARGET_INSTALL_DIR%";
        var qmakeBinary = "@TargetDir@" + "%TARGET_INSTALL_DIR%/bin/qmake";
        addInitQtPatchOperation(component, "linux", qtPath, qmakeBinary, "qt5");

        if (installer.value("SDKToolBinary") == "")
            return;

        component.addOperation("Execute",
                               ["@SDKToolBinary@", "addQt",
                                "--id", component.name,
                                "--name", "Qt %{Qt:Version} GCC 64bit",
                                "--type", "Qt4ProjectManager.QtVersion.Desktop",
                                "--qmake", qmakeBinary,
                                "UNDOEXECUTE",
                                "@SDKToolBinary@", "rmQt", "--id", component.name]);

        var kitName = component.name + "_kit";
        component.addOperation("Execute",
                               ["@SDKToolBinary@", "addKit",
                                "--id", kitName,
                                "--name", "Desktop Qt %{Qt:Version} GCC 64bit",
                                "--Ctoolchain", "x86-linux-generic-elf-64bit",
                                "--Cxxtoolchain", "x86-linux-generic-elf-64bit",
                                "--qt", component.name,
                                "--debuggerengine", "1",
                                "--devicetype", "Desktop",
                                "UNDOEXECUTE",
                                "@SDKToolBinary@", "rmKit", "--id", kitName]);

        // patch/register docs and examples
        var installationPath = installer.value("TargetDir") + "%TARGET_INSTALL_DIR%";
        print("Register documentation and examples for: " + installationPath);
        patchQtExamplesAndDoc(component, installationPath, "Qt-5.11.0");

        // patch qt edition
        var qconfigFile = qtPath + "/mkspecs/qconfig.pri";
        component.addOperation("LineReplace", qconfigFile, "QT_EDITION =", "QT_EDITION = OpenSource");
    }
}

