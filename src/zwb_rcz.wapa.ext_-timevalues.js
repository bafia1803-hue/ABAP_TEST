sap.ui.define([], function () {
    "use strict";

    // Wartości czasu tabeli dni: tekst "hh:mm" (także "-hh:mm" i ponad 99 h) <-> minuty
    return {
        toMinutes: function (text) {
            var match = /^\s*(-?)(\d+):(\d{2})\s*$/.exec(String(text || ""));
            if (!match) {
                return 0;
            }
            var minutes = Number(match[2]) * 60 + Number(match[3]);
            return match[1] ? -minutes : minutes;
        },

        // 0 -> "" (puste jak w tabeli), 90 -> "01:30", -75 -> "-01:15"
        format: function (minutes) {
            if (!minutes) {
                return "";
            }
            var absolute = Math.abs(minutes);
            return (minutes < 0 ? "-" : "")
                + String(Math.floor(absolute / 60)).padStart(2, "0") + ":"
                + String(absolute % 60).padStart(2, "0");
        }
    };
});
