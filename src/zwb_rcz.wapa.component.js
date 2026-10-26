sap.ui.define(["sap/fe/core/AppComponent"], function (AppComponent) {
    "use strict";

    // Cała aplikacja jest opisana w manifest.json i adnotacjach CDS (ZC_WB_RCZ_DAY)
    return AppComponent.extend("zwb.rcz.Component", {
        metadata: {
            manifest: "json"
        }
    });
});
