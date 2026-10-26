sap.ui.define([
    "sap/ui/core/Theming",
    "sap/ui/core/IconPool"
], function (Theming, IconPool) {
    "use strict";

    // Przełącznik trybu jasny / ciemny dla całej aplikacji.
    // Wybór jest zapamiętany w przeglądarce (localStorage) - działa też w nowym oknie
    // ("Wyświetl wszystkie"). Motyw startowy ustawia index.html, żeby nie było mignięcia.
    var STORAGE_KEY = "zwb.rcz.theme";
    var THEMES = { light: "sap_horizon", dark: "sap_horizon_dark" };
    var buttons = [];
    var texts = { dark: "Tryb ciemny", light: "Tryb jasny" };

    function isDark() {
        return Theming.getTheme() === THEMES.dark;
    }

    function icon(name, fallback) {
        return IconPool.getIconInfo(name) ? "sap-icon://" + name : "sap-icon://" + fallback;
    }

    function updateButton(button) {
        if (!button || button.bIsDestroyed) {
            return;
        }
        var dark = isDark();
        // Przycisk pokazuje, na jaki tryb się przełączy
        button.setText(dark ? texts.light : texts.dark);
        button.setTooltip(dark ? texts.light : texts.dark);
        button.setIcon(dark ? icon("light-mode", "lightbulb") : icon("dark-mode", "palette"));
    }

    function refresh() {
        document.documentElement.classList.toggle("zwbRczDark", isDark());
        buttons = buttons.filter(function (button) {
            return !button.bIsDestroyed;
        });
        buttons.forEach(updateButton);
    }

    Theming.attachApplied(refresh);

    return {
        // Teksty przycisku z i18n (wywołuje kontroler strony)
        setTexts: function (darkText, lightText) {
            texts = { dark: darkText || texts.dark, light: lightText || texts.light };
            refresh();
        },

        // Przycisk, który ma pokazywać aktualny stan (tekst i ikonę)
        register: function (button) {
            if (button && buttons.indexOf(button) < 0) {
                buttons.push(button);
            }
            updateButton(button);
        },

        isDark: isDark,

        toggle: function () {
            var mode = isDark() ? "light" : "dark";
            try {
                window.localStorage.setItem(STORAGE_KEY, mode);
            } catch (error) {
                // przeglądarka bez localStorage - wybór działa do zamknięcia okna
            }
            document.documentElement.classList.toggle("zwbRczDark", mode === "dark");
            Theming.setTheme(THEMES[mode]);
        }
    };
});
