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

    // Miejsce ostatniego kliknięcia - środek "bąbla" przy zmianie trybu
    var lastPointer = null;
    document.addEventListener("pointerdown", function (event) {
        lastPointer = { x: event.clientX, y: event.clientY };
    }, true);

    // Zmiana motywu; obietnica kończy się, gdy nowy motyw jest załadowany (najwyżej 3 s)
    function applyMode(mode) {
        return new Promise(function (resolve) {
            var done = false;
            function finish() {
                if (!done) {
                    done = true;
                    Theming.detachApplied(finish);
                    refresh();
                    resolve();
                }
            }
            document.documentElement.classList.toggle("zwbRczDark", mode === "dark");
            if (Theming.getTheme() === THEMES[mode]) {
                finish();
                return;
            }
            Theming.attachApplied(finish);
            Theming.setTheme(THEMES[mode]);
            setTimeout(finish, 3000);
        });
    }

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

        // Przełączenie z animacją "bąbla": nowy tryb rozlewa się kołem od miejsca kliknięcia
        toggle: function () {
            var mode = isDark() ? "light" : "dark";
            try {
                window.localStorage.setItem(STORAGE_KEY, mode);
            } catch (error) {
                // przeglądarka bez localStorage - wybór działa do zamknięcia okna
            }

            var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
            if (!document.startViewTransition || reduceMotion) {
                applyMode(mode);
                return;
            }

            var x = lastPointer ? lastPointer.x : window.innerWidth - 40;
            var y = lastPointer ? lastPointer.y : 40;
            var radius = Math.hypot(Math.max(x, window.innerWidth - x), Math.max(y, window.innerHeight - y));

            // Na czas zmiany bez przejść CSS - w bąblu od razu gotowe kolory nowego trybu
            var root = document.documentElement;
            root.classList.add("zwbRczThemeSwitching");
            var transition = document.startViewTransition(function () {
                return applyMode(mode);
            });
            transition.finished.then(function () {
                root.classList.remove("zwbRczThemeSwitching");
            }, function () {
                root.classList.remove("zwbRczThemeSwitching");
            });
            transition.ready.then(function () {
                document.documentElement.animate({
                    clipPath: [
                        "circle(0px at " + x + "px " + y + "px)",
                        "circle(" + radius + "px at " + x + "px " + y + "px)"
                    ]
                }, {
                    duration: 700,
                    easing: "cubic-bezier(0.4, 0, 0.2, 1)",
                    pseudoElement: "::view-transition-new(root)"
                });
            }).catch(function () {
                // animacja się nie udała - tryb i tak jest przełączony
            });
        }
    };
});
