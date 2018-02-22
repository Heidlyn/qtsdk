/****************************************************************************
**
** Copyright (C) 2018 The Qt Company Ltd.
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
    if (installer.value("os") == "mac") {
        var xcodeVersion = installer.execute("/usr/bin/xcodebuild", new Array("-version"))[0];
        if (xcodeVersion) {
            var version = xcodeVersion.replace( /\D+/g, '');
            if (parseInt(version) <= parseInt(630)) {
                QMessageBox["warning"]("XcodeVersionError",
                        qsTr("You need to update Xcode to newer version!"),
                        qsTr("It is recommeneded to have Xcode version greater than 6.3 for Qt5.9 compilations with clang."));
            }
        }
        else {
            QMessageBox["warning"]("XcodeError",
                qsTr("Xcode installation not found!"),
                qsTr("You need to install Xcode version 6.3 (or newer) and set up Xcode command line tools. Download Xcode from https://developer.apple.com\n"));
        }
    }
    // Determine if this is a online snapshot build
    var snapshotBuild = false;
    var isSnapshotStr = "%ONLINE_SNAPSHOT_BUILD%";
    if (['true', 'yes', '1'].indexOf(isSnapshotStr) >= 0)
        snapshotBuild = true;

    if (snapshotBuild) {
        // Add automatic dependency for preview component
        var autoDependency = component.value("AutoDependOn");
        var dependencyStr = "preview.qt.59.clang_64";
        if (autoDependency) {
            component.setValue("AutoDependOn", autoDependency+","+dependencyStr)
        }
        else {
            component.setValue("AutoDependOn", dependencyStr)
        }
    }
}

function isCommercialLicense()
{
    return installer.value("QT_LICENSE_TYPE").toUpperCase() == "COMMERCIAL";
}

Component.prototype.beginInstallation = function()
{
    installer.setValue(component.name + "_qtpath", "@TargetDir@" + "%TARGET_INSTALL_DIR%");
}

Component.prototype.createOperations = function()
{
    component.createOperations();
    try {
        var qtPath = "@TargetDir@" + "%TARGET_INSTALL_DIR%";
        var qmakeBinary = "@TargetDir@" + "%TARGET_INSTALL_DIR%/bin/qmake";
        addInitQtPatchOperation(component, "mac", qtPath, qmakeBinary, "qt5");

        if (installer.value("SDKToolBinary") == "")
            return;

        component.addOperation("Execute",
                               ["@SDKToolBinary@", "addQt",
                                "--id", component.name,
                                "--name", "Qt %{Qt:Version} clang 64bit",
                                "--type", "Qt4ProjectManager.QtVersion.Desktop",
                                "--qmake", qmakeBinary,
                                "UNDOEXECUTE",
                                "@SDKToolBinary@", "rmQt", "--id", component.name]);

        var kitName = component.name + "_kit";
        component.addOperation("Execute",
                               ["@SDKToolBinary@", "addKit",
                                "--id", kitName,
                                "--name", "Desktop Qt %{Qt:Version} clang 64bit",
                                "--Ctoolchain", "x86-macos-generic-mach_o-64bit",
                                "--Cxxtoolchain", "x86-macos-generic-mach_o-64bit",
                                "--qt", component.name,
                                "--debuggerengine", "256", // DebuggerEngineType::LldbEngineType
                                "--devicetype", "Desktop",
                                "UNDOEXECUTE",
                                "@SDKToolBinary@", "rmKit", "--id", kitName]);

        // patch/register docs and examples
        var installationPath = installer.value("TargetDir") + "%TARGET_INSTALL_DIR%";
        print("Register documentation and examples for: " + installationPath);
        patchQtExamplesAndDoc(component, installationPath, "Qt-5.9.5");

        // is this OpenSource installation?
        if (!isCommercialLicense()) {
            // patch qt edition
            var qconfigFile = qtPath + "/mkspecs/qconfig.pri";
            component.addOperation("LineReplace", qconfigFile, "QT_EDITION =", "QT_EDITION = OpenSource");
        }

        // QTBUG-37650
        patchQtAssistant(component, installationPath, "Qt-5.9.5");

    } catch(e) {
        print(e);
    }
}

//QTBUG-37650
function patchQtAssistant(aComponent, aComponentRootPath, aQtInstallationName)
{
    if (installer.value("os") == "mac") {
        print("Patching qt.conf for Assistant to: " + aComponentRootPath);
        var fileName = aComponentRootPath + "/bin/Assistant.app/Contents/Resources/" + "qt.conf";
        print("qt.conf file: " + fileName);

        aComponent.addOperation("Settings",
            "path=" + fileName,
            "method=add_array_value",
            "key=Paths/Prefix",
            "value=../../..");

        aComponent.addOperation("Settings",
        "path=" + fileName,
        "method=add_array_value",
        "key=Paths/Documentation",
        "value=../../Docs/" + aQtInstallationName);
    }
}

