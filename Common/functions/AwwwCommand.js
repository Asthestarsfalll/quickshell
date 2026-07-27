function clamp(value, fallback, minimum, maximum) {
    const numberValue = Number(value);
    if (!isFinite(numberValue))
        return fallback;
    return Math.max(minimum, Math.min(maximum, numberValue));
}

function namespaceArgs(namespaceName) {
    return ["-n", String(namespaceName || "clavis-desktop")];
}

function daemon(commandPath, namespaceName) {
    return [
        String(commandPath || "awww-daemon"),
        "--layer", "bottom",
        "--namespace", String(namespaceName || "clavis-desktop"),
        "--no-cache"
    ];
}

function query(commandPath, namespaceName) {
    return [String(commandPath || "awww"), "query"]
        .concat(namespaceArgs(namespaceName));
}

function stop(commandPath, namespaceName) {
    return [String(commandPath || "awww"), "kill"]
        .concat(namespaceArgs(namespaceName));
}

function resizeMode(fillMode) {
    switch (String(fillMode || "Fill")) {
    case "Stretch":
        return "stretch";
    case "Fit":
    case "PreserveAspectFit":
        return "fit";
    case "Pad":
        return "no";
    case "Fill":
    case "PreserveAspectCrop":
    default:
        return "crop";
    }
}

function bezier(curve) {
    const fallback = [0.43, 1.19, 1.0, 0.4];
    const source = Array.isArray(curve) && curve.length >= 4
        ? curve : fallback;
    const result = [];
    for (let index = 0; index < 4; index += 1) {
        const value = Number(source[index]);
        const safeValue = isFinite(value)
            ? value : fallback[index];
        result.push(index === 0 || index === 2
            ? Math.max(0, Math.min(1, safeValue))
            : Math.max(-4, Math.min(4, safeValue)));
    }
    return result.join(",");
}

function isColorSource(source) {
    return /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/
        .test(String(source || ""));
}

function colorValue(source) {
    return String(source || "").substring(1).toLowerCase();
}

function transition(value) {
    const supported = [
        "none", "simple", "fade", "left", "right", "top",
        "bottom", "wipe", "wave", "grow", "center", "any",
        "outer", "random"
    ];
    const requested = String(value || "fade");
    return supported.indexOf(requested) !== -1
        ? requested : "fade";
}

function image(commandPath, namespaceName, outputName, source,
               fillMode, options) {
    const settings = options || {};
    const transitionType = transition(settings.type);
    const args = [String(commandPath || "awww"), "img"]
        .concat(namespaceArgs(namespaceName));

    if (outputName)
        args.push("-o", String(outputName));

    args.push("--resize", resizeMode(fillMode));
    args.push("--transition-type", transitionType);

    if (transitionType !== "none") {
        args.push("--transition-fps",
            String(Math.round(clamp(settings.fps, 60, 10, 240))));
    }

    if (transitionType !== "none" && transitionType !== "simple") {
        const durationMs = clamp(settings.durationMs, 1000, 0, 60000);
        args.push("--transition-duration",
            (durationMs / 1000).toFixed(3));
    }

    if (transitionType === "fade")
        args.push("--transition-bezier", bezier(settings.bezierCurve));

    if (transitionType === "wipe" || transitionType === "wave") {
        args.push("--transition-angle",
            String(clamp(settings.angle, 45, 0, 360)));
    }

    if (transitionType === "grow" || transitionType === "outer") {
        args.push("--transition-pos",
            String(settings.position || "center"));
    }

    if (transitionType === "wave") {
        args.push("--transition-wave",
            String(settings.wave || "20,20"));
    }

    args.push("--", String(source || ""));
    return args;
}

function clear(commandPath, namespaceName, outputName, source) {
    const args = [String(commandPath || "awww"), "clear"]
        .concat(namespaceArgs(namespaceName));
    if (outputName)
        args.push("-o", String(outputName));
    args.push(colorValue(source));
    return args;
}

function apply(commandPath, namespaceName, outputName, source,
               fillMode, options) {
    if (isColorSource(source))
        return clear(commandPath, namespaceName, outputName, source);
    return image(commandPath, namespaceName, outputName, source,
        fillMode, options);
}

function supportsDuration(transitionType) {
    return transitionType !== "none" && transitionType !== "simple";
}

function supportsBezier(transitionType) {
    return transitionType === "fade";
}
