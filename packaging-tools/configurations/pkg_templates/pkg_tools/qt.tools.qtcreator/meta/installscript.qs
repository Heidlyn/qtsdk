/****************************************************************************
**
** Copyright (C) 2015 Digia Plc and/or its subsidiary(-ies).
** Contact: http://www.qt-project.org/legal
**
** This file is part of the tools applications of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and Digia.  For licensing terms and
** conditions see http://qt.digia.com/licensing.  For further information
** use the contact form at http://qt.digia.com/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 2.1 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU Lesser General Public License version 2.1 requirements
** will be met: http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** In addition, as a special exception, Digia gives you certain additional
** rights.  These rights are described in the Digia Qt LGPL Exception
** version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3.0 as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU General Public License version 3.0 requirements will be
** met: http://www.gnu.org/copyleft/gpl.html.
**
**
** $QT_END_LICENSE$
**
****************************************************************************/

var native_path_separator = "/";

// constructor
function Component()
{
    component.loaded.connect(this, Component.prototype.loaded);
    installer.installationFinished.connect(this, Component.prototype.installationFinishedPageIsShown);
    installer.finishButtonClicked.connect(this, Component.prototype.installationFinished);
    installer.valueChanged.connect(this, Component.prototype.reactOnTargetDirChange);
    if ("%QTC_IS_STANDALONE_INSTALLER%" == "true")
        installer.setDefaultPageVisible(QInstaller.ComponentSelection, false);

    if (installer.value("os") == "win") {
        // Creator needs vcredist 32bit on windows
        component.addDependency("qt.tools.vcredist_msvc%QTC_MSVC%_x86");
        if (systemInfo.currentCpuArchitecture == "x86_64")
            component.addDependency("qt.tools.vcredist_msvc%QTC_MSVC%_x64");
    }

    if (installer.value("os") == "x11") {
        // set installation directory
        installer.setValue("EmbeddedInstallationRootDir", "/usr/local/Trolltech");
        installer.setValue("EmbeddedToolchainDir", "/usr/local/angstrom/arm");
    }

    // set the default values to SDKToolBinary and QtCreatorInstallerSettingsFile
    Component.prototype.reactOnTargetDirChange("TargetDir", installer.value("TargetDir"));
}

Component.prototype.loaded = function()
{
    try {
        if (installer.value("os") == "win" && installer.isInstaller())
            installer.addWizardPageItem(component, "AssociateCommonFiletypesForm", QInstaller.TargetDirectory);
    } catch(e) {
        print(e);
    }
}

Component.prototype.beginInstallation = function()
{
    if (installer.value("os") === "win")
        component.addStopProcessForUpdateRequest(component.qtCreatorBinaryPath);
}

Component.prototype.reactOnTargetDirChange = function(key, value)
{
    if (key == "TargetDir") {
        component.qtCreatorBinaryPath = value;
        if (installer.value("os") == "win") {
            installer.setValue("QtCreatorInstallerSettingsFile", value + "/%TARGET_INSTALL_DIR%/share/qtcreator/QtProject/QtCreator.ini");
            installer.setValue("SDKToolBinary", value + "\\%TARGET_INSTALL_DIR%\\bin\\sdktool.exe");
            component.qtCreatorBinaryPath = value + "\\%TARGET_INSTALL_DIR%\\bin\\qtcreator.exe";
            component.qtCreatorBinaryPath = component.qtCreatorBinaryPath.replace(/\//g, "\\");
        } else if (installer.value("os") == "mac") {
            installer.setValue("QtCreatorInstallerSettingsFile", value + "/%TARGET_INSTALL_DIR%/Qt Creator.app/Contents/Resources/QtProject/QtCreator.ini");
            installer.setValue("SDKToolBinary", value + "/%TARGET_INSTALL_DIR%/Qt Creator.app/Contents/Resources/sdktool");
            component.qtCreatorBinaryPath = value + "/%TARGET_INSTALL_DIR%/Qt Creator.app/Contents/MacOS/Qt Creator";
            // fix duplicate forward slashes in path
            component.qtCreatorBinaryPath = component.qtCreatorBinaryPath.replace(/\/+/g, "/");
        } else {
            installer.setValue("QtCreatorInstallerSettingsFile", value + "/%TARGET_INSTALL_DIR%/share/qtcreator/QtProject/QtCreator.ini");
            installer.setValue("SDKToolBinary", value + "/%TARGET_INSTALL_DIR%/libexec/qtcreator/sdktool");
            component.qtCreatorBinaryPath = value + "/%TARGET_INSTALL_DIR%/bin/qtcreator";
            // fix duplicate forward slashes in path
            component.qtCreatorBinaryPath = component.qtCreatorBinaryPath.replace(/\/+/g, "/");
        }
    }
}

registerCommonWindowsFileTypeExtensions = function()
{
    var headerExtensions = new Array("h", "hh", "hxx", "h++", "hpp");

    for (var i = 0; i < headerExtensions.length; ++i) {
        component.addOperation("RegisterFileType",
                               headerExtensions[i],
                               component.qtCreatorBinaryPath + " -client \"%1\"",
                               "C++ Header file",
                               "text/plain",
                               component.qtCreatorBinaryPath + ",3",
                               "ProgId=QtProject.QtCreator." + headerExtensions[i]);
    }

    var cppExtensions = new Array("cc", "cxx", "c++", "cp", "cpp");

    for (var i = 0; i < cppExtensions.length; ++i) {
        component.addOperation("RegisterFileType",
                               cppExtensions[i],
                               component.qtCreatorBinaryPath + " -client \"%1\"",
                               "C++ Source file",
                               "text/plain",
                               component.qtCreatorBinaryPath + ",2",
                               "ProgId=QtProject.QtCreator." + cppExtensions[i]);
    }

    component.addOperation("RegisterFileType",
                           "c",
                           component.qtCreatorBinaryPath + " -client \"%1\"",
                           "C Source file",
                           "text/plain",
                           component.qtCreatorBinaryPath + ",1",
                           "ProgId=QtProject.QtCreator.c");
}

registerWindowsFileTypeExtensions = function()
{
    component.addOperation("RegisterFileType",
                           "ui",
                           component.qtCreatorBinaryPath + " -client \"%1\"",
                           "Qt UI file",
                           "text/plain",
                           component.qtCreatorBinaryPath + ",4",
                           "ProgId=QtProject.QtCreator.ui");
    component.addOperation("RegisterFileType",
                           "pro",
                           component.qtCreatorBinaryPath + " -client \"%1\"",
                           "Qt Project file",
                           "text/plain",
                           component.qtCreatorBinaryPath + ",5",
                           "ProgId=QtProject.QtCreator.pro");
    component.addOperation("RegisterFileType",
                           "pri",
                           component.qtCreatorBinaryPath + " -client \"%1\"",
                           "Qt Project Include file",
                           "text/plain",
                           component.qtCreatorBinaryPath + ",6",
                           "ProgId=QtProject.QtCreator.pri");
    component.addOperation("RegisterFileType",
                           "qbs",
                           component.qtCreatorBinaryPath + " -client \"%1\"",
                           "Qbs Project file",
                           "text/plain",
                           component.qtCreatorBinaryPath + ",5",
                           "ProgId=QtProject.QtCreator.qbs");
    component.addOperation("RegisterFileType",
                           "qs",
                           component.qtCreatorBinaryPath + " -client \"%1\"",
                           "Qt Script file",
                           "text/plain",
                           component.qtCreatorBinaryPath + ",0",
                           "ProgId=QtProject.QtCreator.qs");
    component.addOperation("RegisterFileType",
                           "qml",
                           component.qtCreatorBinaryPath + " -client \"%1\"",
                           "Qt Quick Markup language file",
                           "text/plain",
                           component.qtCreatorBinaryPath + ",7",
                           "ProgId=QtProject.QtCreator.qml");
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations and afterwards set some registry settings
    component.createOperations();
    var maintenanceToolPath;

    if (installer.value("os") == "win") {
        component.addOperation("CreateShortcut",
                               component.qtCreatorBinaryPath,
                               "@StartMenuDir@\\Qt Creator %QTC_DISPLAY_VERSION% (Community).lnk",
                               "workingDirectory=@homeDir@");

        registerWindowsFileTypeExtensions();

        if (component.userInterface("AssociateCommonFiletypesForm").AssociateCommonFiletypesCheckBox.checked)
            registerCommonWindowsFileTypeExtensions();

        maintenanceToolPath = installer.value("TargetDir") + "/MaintenanceTool.exe";
    }
    if (installer.value("os") == "x11") {
        component.addOperation("InstallIcons", installer.value("TargetDir") + "%TARGET_INSTALL_DIR%/share/icons" );
        component.addOperation("CreateDesktopEntry",
                               "DigiaQt-qtcreator-community.desktop",
                               "Type=Application\nExec=" + component.qtCreatorBinaryPath + "\nName=Qt Creator (Community)\nGenericName=The IDE of choice for Qt development.\nIcon=QtProject-qtcreator\nStartupWMClass=qtcreator\nTerminal=false\nCategories=Development;IDE;Qt;\nMimeType=text/x-c++src;text/x-c++hdr;text/x-xsrc;application/x-designer;application/vnd.qt.qmakeprofile;application/vnd.qt.xml.resource;text/x-qml;text/x-qt.qml;text/x-qt.qbs;");
        maintenanceToolPath = installer.value("TargetDir") + "/MaintenanceTool";
    }
    if (installer.value("os") == "mac") {
        maintenanceToolPath = installer.value("TargetDir")
                + "/MaintenanceTool.app/Contents/MacOS/MaintenanceTool";
    }

    var settingsFile = installer.value("QtCreatorInstallerSettingsFile");
    if (!installer.isOfflineOnly()) {
        // Configure UpdateInfo plugin
        component.addOperation("Settings", "path="+settingsFile, "method=set",
                               "key=Updater/MaintenanceTool",
                               "value="+maintenanceToolPath);
    }
}

function isRoot()
{
    if (installer.value("os") == "x11" || installer.value("os") == "mac")
    {
        var id = installer.execute("/usr/bin/id", new Array("-u"))[0];
        id = id.replace(/(\r\n|\n|\r)/gm,"");
        if (id === "0")
        {
            return true;
        }
    }
    return false;
}

Component.prototype.installationFinishedPageIsShown = function()
{
    isroot = isRoot();
    try {
        if (component.installed && installer.isInstaller() && installer.status == QInstaller.Success && !isroot)
            installer.addWizardPageItem( component, "LaunchQtCreatorCheckBoxForm", QInstaller.InstallationFinished );
    } catch(e) {
        print(e);
    }
}

Component.prototype.installationFinished = function()
{
    try {
        if (component.installed && installer.isInstaller() && installer.status == QInstaller.Success && !isroot) {
            var isLaunchQtCreatorCheckBoxChecked = component.userInterface("LaunchQtCreatorCheckBoxForm").launchQtCreatorCheckBox.checked;
            if (isLaunchQtCreatorCheckBoxChecked)
                installer.executeDetached(component.qtCreatorBinaryPath, new Array(), "@homeDir@");
        }
    } catch(e) {
        print(e);
    }
}

