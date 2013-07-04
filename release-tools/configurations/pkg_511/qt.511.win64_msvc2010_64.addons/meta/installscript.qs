/* This file is part of the Qt SDK

*/

// constructor
function Component()
{
}


Component.prototype.isDefault = function()
{
    if (installer.environmentVariable("VS100COMNTOOLS")) {
        return true;
    }
    return false;
}


Component.prototype.createOperations = function()
{
    component.createOperations();
    component.addOperation("QtPatch",
                            "windows",
                            "@TargetDir@/%TARGET_INSTALL_DIR%",
                            "QmakeOutputInstallerKey=" + qmakeOutputInstallerKey(component),
                            "qt5");
}


