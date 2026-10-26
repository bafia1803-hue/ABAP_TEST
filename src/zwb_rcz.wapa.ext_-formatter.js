sap.ui.define([], function () {
    "use strict";

    // Formatery dla fragmentów tabeli. OData V4 może podać liczbę jako tekst ("0"), stąd Number().
    return {
        isPositive: function (value) {
            return Number(value) > 0;
        }
    };
});
