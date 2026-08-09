#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

require_text() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

reject_text() {
    if grep -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

dialog=Widgets/common/MaterialDialog.qml
button=Widgets/common/DialogActionButton.qml

require_text "$dialog" 'property string dialogTitle: ""'
require_text "$dialog" 'property string messageText: ""'
require_text "$dialog" 'property Component actionsComponent'
require_text "$dialog" 'Overlay.modal: Rectangle'
require_text "$dialog" 'color: "transparent"'
require_text "$dialog" 'dim: false'
require_text "$dialog" 'BlurService.backgroundColor('
require_text "$dialog" 'Appearance.m3colors.m3surfaceContainerHigh'
require_text "$dialog" 'readonly property alias blurRegionItem: dialogSurface.blurRegionItem'
require_text "$dialog" 'visible: root.visible'
require_text "$dialog" 'Appearance.colors.colOnSurfaceVariant'
require_text "$dialog" 'Typography.headlineSmall'
require_text "$dialog" 'Typography.bodyMedium'
reject_text "$dialog" 'title: root.dialogTitle'

require_text "$button" 'MaterialRippleButton {'
require_text "$button" 'property bool filled: false'
require_text "$button" 'Appearance.colors.colPrimary'
require_text "$button" 'Typography.labelLarge'
reject_text "$button" 'signal clicked()'
reject_text "$button" 'border.width: root.activeFocus'
reject_text "$button" 'backgroundContent: Rectangle'

for file in \
    Modules/Launcher/SpotlightResultsPanel.qml \
    Modules/ControlCenter/AutostartPage.qml \
    Modules/Sidebars/Right/NetworkContent.qml \
    Modules/Sidebars/Right/BluetoothContent.qml
do
    require_text "$file" 'MaterialDialog {'
done

if rg -n '^[[:space:]]*Dialog[[:space:]]*\{' Modules >/dev/null; then
    fail "a page-local raw Dialog implementation remains"
fi

require_text Modules/Launcher/SpotlightResultsPanel.qml \
    'dialogTitle: qsTr("清空剪贴板历史？")'
require_text Modules/Launcher/SpotlightResultsPanel.qml \
    'messageText: qsTr("此操作会清除 cliphist 中的全部历史记录，无法撤销。")'
require_text Modules/Launcher/SpotlightResultsPanel.qml \
    'readonly property Item modalBlurRegionItem: clearDialog.blurRegionItem'
require_text Modules/Launcher/LauncherWindow.qml \
    'resultsPanel.modalBlurRegionItem'
reject_text Modules/Launcher/SpotlightResultsPanel.qml \
    'text: clearDialog.title'
reject_text Modules/Launcher/SpotlightResultsPanel.qml \
    'colErrorContainer'

echo "dialog architecture tests passed"
