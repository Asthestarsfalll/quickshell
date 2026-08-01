.pragma library

function isValidHandshake(response) {
    return response
        && response.product === "clavis-key"
        && response.protocols
        && typeof response.protocols === "object"
        && Array.isArray(response.features);
}

function protocolCompatible(keyAvailable, protocols, name, requiredVersion) {
    return keyAvailable
        && protocols
        && Number(protocols[String(name)]) === Number(requiredVersion);
}

function hasFeature(keyAvailable, features, name) {
    return keyAvailable
        && Array.isArray(features)
        && features.indexOf(String(name)) >= 0;
}

function nativePluginsCompatible(expectedRelease, expectedCommit,
                                 pluginRelease, pluginCommit) {
    return (expectedRelease === "" || pluginRelease === expectedRelease)
        && (expectedCommit === "" || pluginCommit === expectedCommit);
}

function evaluate(response, expectedRelease, expectedCommit,
                  pluginRelease, pluginCommit, requiredProtocols,
                  requiredClipboardFeatures) {
    if (!isValidHandshake(response)) {
        return {
            keyAvailable: false,
            errorCode: "invalid_version_handshake",
            warningCode: "",
            coreCompatible: false,
            clipboardCompatible: false,
            sysmonCompatible: false
        };
    }

    const protocols = response.protocols;
    const features = response.features;
    const release = String(response.release || "");
    const commit = String(response.commit || "");
    const nativeCompatible = nativePluginsCompatible(
        expectedRelease, expectedCommit, pluginRelease, pluginCommit);
    const coreCompatible = nativeCompatible
        && protocolCompatible(
            true, protocols, "core", requiredProtocols.core);
    let clipboardFeaturesAvailable = true;
    for (let index = 0; index < requiredClipboardFeatures.length;
            index += 1) {
        if (!hasFeature(true, features, requiredClipboardFeatures[index])) {
            clipboardFeaturesAvailable = false;
            break;
        }
    }
    const clipboardCompatible = coreCompatible
        && protocolCompatible(
            true, protocols, "clipboard", requiredProtocols.clipboard)
        && clipboardFeaturesAvailable;
    const sysmonCompatible = coreCompatible
        && protocolCompatible(
            true, protocols, "sysmon", requiredProtocols.sysmon);
    const releaseMatches = expectedRelease === "" || release === ""
        || expectedRelease === release;
    const commitMatches = expectedCommit === "" || commit === ""
        || expectedCommit === commit;

    let errorCode = "";
    let warningCode = "";
    if (!protocolCompatible(
            true, protocols, "core", requiredProtocols.core)) {
        errorCode = "core_protocol_incompatible";
    } else if (!nativeCompatible) {
        errorCode = "native_plugin_release_mismatch";
    } else if (!releaseMatches || !commitMatches) {
        warningCode = "release_mismatch";
    }
    return {
        keyAvailable: true,
        errorCode: errorCode,
        warningCode: warningCode,
        coreCompatible: coreCompatible,
        clipboardCompatible: clipboardCompatible,
        sysmonCompatible: sysmonCompatible
    };
}
