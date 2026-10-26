sap.ui.define([
    "sap/fe/core/PageController",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator",
    "sap/ui/core/routing/History",
    "sap/ui/core/format/DateFormat",
    "zwb/rcz/ext/ThemeSwitch"
], function (PageController, Filter, FilterOperator, History, DateFormat, ThemeSwitch) {
    "use strict";

    // Ekran wszystkich komunikatów (manifest.json -> trasa Messages: Messages/{pernr}/{fpper}).
    // Dane: encja TimeMessage (ZC_WB_RCZ_MSG), filtr: numer osobowy i miesiąc komunikatu.

    var ROUTE = "Messages";
    var LIST_ROUTE = "TimeResultDayList";

    return PageController.extend("zwb.rcz.ext.view.Messages", {

        // Przycisk "Tryb ciemny / Tryb jasny" w nagłówku strony
        onToggleTheme: function () {
            ThemeSwitch.toggle();
        },

        onInit: function () {
            if (PageController.prototype.onInit) {
                PageController.prototype.onInit.apply(this, arguments);
            }
            ThemeSwitch.register(this.byId("themeButton"));
            var router = this.getAppComponent().getRouter();
            router.getRoute(ROUTE).attachPatternMatched(function (event) {
                this._load(event.getParameter("arguments"));
            }, this);

            // Widok powstaje przy pierwszym wejściu - wtedy zdarzenie trasy już minęło
            var hash = router.getHashChanger ? router.getHashChanger().getHash() : "";
            var routeInfo = router.getRouteInfoByHash ? router.getRouteInfoByHash(hash) : null;
            if (routeInfo && routeInfo.name === ROUTE) {
                this._load(routeInfo.arguments);
            }
        },

        onNavBack: function () {
            if (History.getInstance().getPreviousHash() !== undefined) {
                window.history.go(-1);
            } else {
                this.getAppComponent().getRouter().navTo(LIST_ROUTE, {}, true);
            }
        },

        _load: function (args) {
            var board = this.byId("messageBoard");
            var pernr = args.pernr;
            var fpper = args.fpper;
            var month = DateFormat.getDateInstance({ pattern: "LLLL yyyy" })
                .format(new Date(Number(fpper.slice(0, 4)), Number(fpper.slice(4, 6)) - 1, 1));
            var data = {
                title: this._getText("msgPageHeading", [month]),
                subtitle: this._getText("msgPageSubtitle", [String(pernr).replace(/^0+/, ""), fpper]),
                messages: [],
                loading: true
            };
            board.setData(data);

            var list = this.getAppComponent().getModel().bindList("/TimeMessage", undefined, undefined, [
                new Filter("Pernr", FilterOperator.EQ, pernr),
                new Filter("Period", FilterOperator.EQ, fpper)
            ]);
            list.requestContexts(0, 5000)
                .then(function (contexts) {
                    data.messages = contexts.map(function (context) {
                        return context.getObject();
                    });
                })
                .catch(function (error) {
                    // eslint-disable-next-line no-console
                    console.error("[ZWB_RCZ] Komunikaty", error);
                })
                .finally(function () {
                    data.loading = false;
                    board.setData(data);
                });
        },

        _getText: function (key, args) {
            return this.getAppComponent().getModel("i18n").getResourceBundle().getText(key, args);
        }
    });
});
