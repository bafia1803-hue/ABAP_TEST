sap.ui.define([
    "zwb/rcz/ext/MessageList"
], function (MessageList) {
    "use strict";

    // Panel komunikatów dnia wysuwany od dołu; ekran dzieli się na tabelę (u góry) i panel.
    // options: { getText(key, args), onShowAll() }

    function create(tag, className, text) {
        var element = document.createElement(tag);
        if (className) {
            element.className = className;
        }
        if (text !== undefined) {
            element.textContent = text;
        }
        return element;
    }

    function MessagePanel(options) {
        this._options = options;
        this._panel = null;
        this._request = 0;
        document.addEventListener("keydown", function (event) {
            if (event.key === "Escape" && this._panel) {
                this.close();
            }
        }.bind(this));
    }

    MessagePanel.prototype._build = function () {
        var text = this._options.getText;
        var panel = create("section", "zwbRczPanel");
        panel.setAttribute("role", "dialog");

        var head = create("div", "zwbRczPanelHead");
        var titles = create("div", "zwbRczPanelTitles");
        this._title = create("div", "zwbRczPanelTitle");
        this._chips = create("div", "zwbRczPanelChips");
        titles.appendChild(this._title);
        titles.appendChild(this._chips);

        var showAll = create("button", "zwbRczPanelButton", text("msgShowAll"));
        showAll.type = "button";
        showAll.addEventListener("click", function () {
            this._options.onShowAll();
        }.bind(this));

        var close = create("button", "zwbRczPanelClose");
        close.type = "button";
        close.title = text("msgClose");
        close.setAttribute("aria-label", text("msgClose"));
        close.innerHTML = "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><path d=\"M6 6l12 12M18 6L6 18\" /></svg>";
        close.addEventListener("click", this.close.bind(this));

        head.appendChild(titles);
        head.appendChild(showAll);
        head.appendChild(close);

        this._list = create("div", "zwbRczPanelList");
        panel.appendChild(create("div", "zwbRczPanelGrip"));
        panel.appendChild(head);
        panel.appendChild(this._list);
        document.body.appendChild(panel);
        this._panel = panel;

        window.requestAnimationFrame(function () {
            window.requestAnimationFrame(function () {
                panel.classList.add("is-open");
                document.body.classList.add("zwbRczSplit");
            });
        });
    };

    // Otwarcie (albo przełączenie na inny dzień) z danymi wczytywanymi przez obietnicę
    MessagePanel.prototype.open = function (title, messagesPromise) {
        if (!this._panel) {
            this._build();
        }
        var request = ++this._request;
        this._title.textContent = title;
        this._chips.innerHTML = "";
        this._panel.classList.add("is-loading");

        messagesPromise.then(function (messages) {
            if (request !== this._request || !this._panel) {
                return;
            }
            this._panel.classList.remove("is-loading");
            this._renderChips(messages);
            MessageList.render(this._list, messages, { getText: this._options.getText, showDate: false });
            this._list.scrollTop = 0;
        }.bind(this)).catch(function (error) {
            // eslint-disable-next-line no-console
            console.error("[ZWB_RCZ] Komunikaty dnia", error);
            if (this._panel) {
                this._panel.classList.remove("is-loading");
            }
        }.bind(this));
    };

    MessagePanel.prototype._renderChips = function (messages) {
        var counts = MessageList.count(messages);
        var text = this._options.getText;
        [["error", "msgErrors"], ["warning", "msgWarnings"], ["info", "msgInfos"]].forEach(function (entry) {
            if (!counts[entry[0]]) {
                return;
            }
            var chip = create("span", "zwbRczChip is-" + entry[0]);
            chip.appendChild(MessageList.icon(entry[0]));
            chip.appendChild(create("span", "", text(entry[1]) + ": " + counts[entry[0]]));
            this._chips.appendChild(chip);
        }, this);
    };

    MessagePanel.prototype.close = function () {
        var panel = this._panel;
        if (!panel) {
            return;
        }
        this._panel = null;
        this._request++;
        panel.classList.remove("is-open");
        document.body.classList.remove("zwbRczSplit");
        setTimeout(function () {
            panel.remove();
        }, 320);
    };

    return MessagePanel;
});
