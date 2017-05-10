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
        // Indicate in DisplayName and Description that this is a snapshot build
        var displayName = component.value("DisplayName");
        var description = component.value("Description");
        component.setValue("DisplayName", displayName + " Beta snapshot (#%BUILD_NUMBER%)")
        component.setValue("Description", description + " Beta snapshot (#%BUILD_NUMBER%)")
    }

    if ((installer.value("os") == "win")
            && !installer.isOfflineOnly()) {
        // Enable the right toolchains
        var msvc2013 = !!installer.environmentVariable("VS120COMNTOOLS");
        var msvc2015 = !!installer.environmentVariable("VS140COMNTOOLS");
        var msvc2017 = !!installer.environmentVariable("VS150COMNTOOLS");

        var android_armv7 = installer.componentByName("qt.59.android_armv7");
        var msvc2015_winrt_armv7 = installer.componentByName("qt.59.win64_msvc2015_winrt_armv7");
        var msvc2015_winrt_x64 = installer.componentByName("qt.59.win64_msvc2015_winrt_x64");
        var msvc2015_winrt_x86 = installer.componentByName("qt.59.win64_msvc2015_winrt_x86");

        // first reset the latest Qt5.x.x package default values to false
        installer.componentByName("qt.59.win32_mingw53").setValue("Default", "false");
        installer.componentByName("qt.59.win64_msvc2013_64").setValue("Default", "false");
        installer.componentByName("qt.59.win32_msvc2015").setValue("Default", "false");
        installer.componentByName("qt.59.win64_msvc2015_64").setValue("Default", "false");
        installer.componentByName("qt.59.win64_msvc2017_64").setValue("Default", "false");

        if (android_armv7)
            android_armv7.setValue("Default", "false");
        if (msvc2015_winrt_armv7)
            msvc2015_winrt_armv7.setValue("Default", "false");
        if (msvc2015_winrt_x64)
            msvc2015_winrt_x64.setValue("Default", "false");
        if (msvc2015_winrt_x86)
            msvc2015_winrt_x86.setValue("Default", "false");

        if (!snapshotBuild) {
            // if 32bit windows hide the 64bit packages
            if (installer.environmentVariable("ProgramFiles(x86)") == "" ) {
                installer.componentByName("qt.59.win64_msvc2013_64").setValue("Virtual", "true");
                installer.componentByName("qt.59.win64_msvc2015_64").setValue("Virtual", "true");
                installer.componentByName("qt.59.win64_msvc2017_64").setValue("Virtual", "true");
            }

            // now try to determine which tool chains to select by default
            if (msvc2013) {
                // if 64bit machine
                if (!(installer.environmentVariable("ProgramFiles(x86)") == "")) {
                    installer.componentByName("qt.59.win64_msvc2013_64").setValue("Default", "true");
                }
            }
            if (msvc2015) {
                // if 64bit machine
                if (!(installer.environmentVariable("ProgramFiles(x86)") == "")) {
                    installer.componentByName("qt.59.win64_msvc2015_64").setValue("Default", "true");
                } else {
                    installer.componentByName("qt.59.win32_msvc2015").setValue("Default", "true");
                }
            }
            if (msvc2017) {
                // if 64bit machine
                if (!(installer.environmentVariable("ProgramFiles(x86)") == "")) {
                    installer.componentByName("qt.59.win64_msvc2017_64").setValue("Default", "true");
                }
            }
            // if no msvc toolkits detected, choose mingw by default
            if (!msvc2013 && !msvc2015) {
                installer.componentByName("qt.59.win32_mingw53").setValue("Default", "true");
            }
        }
    }
}


Component.prototype.createOperations = function()
{
    component.createOperations();
}

