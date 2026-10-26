sap.ui.define([
    "zwb/rcz/ext/ThemeSwitch"
], function (ThemeSwitch) {
    "use strict";

    // Przyciski na górze strony listy dni (manifest: content.header.actions).
    // Fiori Elements wywołuje je jako zwykłe funkcje modułu (FPMHelper.actionWrapper),
    // a nie jako metody rozszerzenia kontrolera - dlatego osobny moduł.
    // ListReportExt rejestruje się tu w onInit (setListReport).
    var listReport = null;

    return {
        setListReport: function (extension) {
            listReport = extension;
        },

        // "Komunikaty": ekran wszystkich komunikatów okresu
        openAllMessages: function () {
            if (listReport) {
                listReport.openAllMessages();
            }
        },

        // "Tryb ciemny / Tryb jasny"
        toggleTheme: function () {
            ThemeSwitch.toggle();
        }
    };
});
