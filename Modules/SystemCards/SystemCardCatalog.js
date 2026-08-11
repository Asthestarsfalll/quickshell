.pragma library

// This is the single source of truth for the ten system cards.  Layout
// algorithms consume the metadata from here; they do not maintain a second
// list of cards of their own.
var cardDefinitions = [
    {
        id: "time",
        nameKey: "时钟",
        name: qsTr("时钟"),
        icon: "schedule",
        columnSpan: 2,
        rowSpan: 2,
        requiresSystemMonitor: false,
        desktopWidth: 340,
        desktopHeight: 250
    },
    {
        id: "battery",
        nameKey: "电池",
        name: qsTr("电池"),
        icon: "battery_full",
        columnSpan: 1,
        rowSpan: 2,
        requiresSystemMonitor: true,
        desktopWidth: 220,
        desktopHeight: 300
    },
    {
        id: "cpu",
        nameKey: "CPU",
        name: qsTr("CPU"),
        icon: "memory",
        columnSpan: 1,
        rowSpan: 1,
        requiresSystemMonitor: true,
        desktopWidth: 280,
        desktopHeight: 220
    },
    {
        id: "gpu",
        nameKey: "GPU",
        name: qsTr("GPU"),
        icon: "developer_board",
        columnSpan: 1,
        rowSpan: 1,
        requiresSystemMonitor: true,
        desktopWidth: 280,
        desktopHeight: 220
    },
    {
        id: "memoryUsed",
        nameKey: "内存",
        name: qsTr("内存"),
        icon: "memory_alt",
        columnSpan: 1,
        rowSpan: 1,
        requiresSystemMonitor: true,
        desktopWidth: 280,
        desktopHeight: 220
    },
    {
        id: "wifi",
        nameKey: "Wi-Fi",
        name: qsTr("Wi-Fi"),
        icon: "wifi",
        columnSpan: 1,
        rowSpan: 1,
        requiresSystemMonitor: false,
        desktopWidth: 280,
        desktopHeight: 220
    },
    {
        id: "network",
        nameKey: "网络",
        name: qsTr("网络"),
        icon: "swap_vert",
        columnSpan: 2,
        rowSpan: 1,
        requiresSystemMonitor: true,
        desktopWidth: 360,
        desktopHeight: 230
    },
    {
        id: "storage",
        nameKey: "存储",
        name: qsTr("存储"),
        icon: "storage",
        columnSpan: 3,
        rowSpan: 1,
        requiresSystemMonitor: true,
        desktopWidth: 420,
        desktopHeight: 230
    },
    {
        id: "calendar",
        nameKey: "日历",
        name: qsTr("日历"),
        icon: "calendar_month",
        columnSpan: 1,
        rowSpan: 1,
        requiresSystemMonitor: false,
        desktopWidth: 280,
        desktopHeight: 220
    },
    {
        id: "weather",
        nameKey: "天气",
        name: qsTr("天气"),
        icon: "cloud",
        columnSpan: 3,
        rowSpan: 1,
        requiresSystemMonitor: false,
        desktopWidth: 440,
        desktopHeight: 280
    }
];

var defaultAnchors = {
    time: { column: 0, row: 0 },
    battery: { column: 2, row: 0 },
    cpu: { column: 0, row: 2 },
    gpu: { column: 1, row: 2 },
    memoryUsed: { column: 2, row: 2 },
    wifi: { column: 0, row: 3 },
    network: { column: 1, row: 3 },
    storage: { column: 0, row: 4 },
    calendar: { column: 0, row: 5 },
    weather: { column: 0, row: 6 }
};

function cloneDefinition(definition) {
    var result = {};
    for (var key in definition)
        result[key] = definition[key];
    return result;
}

function all() {
    return cardDefinitions.map(cloneDefinition);
}

function ids() {
    return cardDefinitions.map(function(definition) {
        return definition.id;
    });
}

function definitionFor(id) {
    for (var index = 0; index < cardDefinitions.length; index += 1) {
        if (cardDefinitions[index].id === id)
            return cardDefinitions[index];
    }
    return null;
}

function nameFor(id) {
    var definition = definitionFor(id);
    return definition ? qsTr(definition.nameKey) : String(id);
}

function defaultAnchorFor(id) {
    var anchor = defaultAnchors[id];
    return anchor
        ? { column: anchor.column, row: anchor.row }
        : { column: 0, row: 0 };
}

function sidebarDefinitions(activeIds) {
    var allowed = activeIds || ids();
    return cardDefinitions.filter(function(definition) {
        return allowed.indexOf(definition.id) !== -1;
    }).map(cloneDefinition);
}
