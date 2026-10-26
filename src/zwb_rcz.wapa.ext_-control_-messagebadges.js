sap.ui.define([
    "sap/ui/core/Control",
    "sap/ui/core/IconPool"
], function (Control, IconPool) {
    "use strict";

    // Komórka "Komunikaty": ikona błędu + liczba i ikona ostrzeżenia + liczba.
    // Ikona jest renderowana TYLKO, gdy liczba > 0 (bez wiązania "visible", które w kolumnie
    // Fiori Elements nie działało). Liczby mogą przyjść jako tekst ("0"), stąd Number().
    var BADGES = [
        { property: "errors", key: "error", icon: "error" },
        { property: "warnings", key: "warning", icon: "alert" }
    ];

    return Control.extend("zwb.rcz.ext.control.MessageBadges", {
        metadata: {
            properties: {
                errors: { type: "any", defaultValue: 0 },
                warnings: { type: "any", defaultValue: 0 }
            }
        },

        renderer: {
            apiVersion: 2,
            render: function (rm, control) {
                rm.openStart("div", control);
                rm.class("zwbRczMsgCell");
                rm.openEnd();
                BADGES.forEach(function (badge) {
                    var count = Number(control.getProperty(badge.property)) || 0;
                    if (count <= 0) {
                        return;
                    }
                    var info = IconPool.getIconInfo(badge.icon);
                    rm.openStart("span");
                    rm.class("zwbRczMsgBadge");
                    rm.class("is-" + badge.key);
                    rm.openEnd();
                    rm.openStart("span");
                    rm.class("zwbRczMsgBadgeIcon");
                    rm.style("font-family", info ? "'" + info.fontFamily + "'" : "SAP-icons");
                    rm.openEnd();
                    rm.text(info ? info.content : "");
                    rm.close("span");
                    rm.openStart("span");
                    rm.class("zwbRczMsgCount");
                    rm.openEnd();
                    rm.text(String(count));
                    rm.close("span");
                    rm.close("span");
                });
                rm.close("div");
            }
        }
    });
});
