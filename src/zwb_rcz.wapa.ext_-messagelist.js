sap.ui.define([
    "sap/ui/core/format/DateFormat"
], function (DateFormat) {
    "use strict";

    // Lista komunikatów (wspólna dla panelu dnia i ekranu wszystkich komunikatów):
    // grupy Błędy / Ostrzeżenia / Pozostałe (błędy na górze), w grupie wg daty i godziny.
    // Komunikat: { Tykom, Tekom, Dakom, BeginTime, EndTime, Msgid, Msgno, SeverityRank }

    var GROUPS = [
        { rank: 1, key: "error", textKey: "msgErrors" },
        { rank: 2, key: "warning", textKey: "msgWarnings" },
        { rank: 3, key: "info", textKey: "msgInfos" }
    ];

    var ICONS = {
        error: "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"11\" />"
            + "<path d=\"M12 6.5v7\" /><circle class=\"dot\" cx=\"12\" cy=\"17.25\" r=\"1.4\" /></svg>",
        warning: "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><path class=\"shape\" d=\"M12 1.8 23 21.5H1z\" />"
            + "<path d=\"M12 8.5v6\" /><circle class=\"dot\" cx=\"12\" cy=\"18\" r=\"1.4\" /></svg>",
        info: "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"11\" />"
            + "<path d=\"M12 10.5v7\" /><circle class=\"dot\" cx=\"12\" cy=\"7\" r=\"1.4\" /></svg>"
    };

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

    function rankOf(message) {
        return message.SeverityRank || (message.Tykom === "E" ? 1 : message.Tykom === "W" ? 2 : 3);
    }

    function keyOf(rank) {
        return rank === 1 ? "error" : rank === 2 ? "warning" : "info";
    }

    function toDate(isoDay) {
        var parts = String(isoDay).split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    function sortMessages(messages) {
        return messages.slice().sort(function (a, b) {
            return (rankOf(a) - rankOf(b))
                || String(a.Dakom).localeCompare(String(b.Dakom))
                || String(a.BeginTime || "").localeCompare(String(b.BeginTime || ""))
                || String(a.Seqnr || "").localeCompare(String(b.Seqnr || ""));
        });
    }

    return {
        icon: function (severity) {
            var element = create("span", "zwbRczMsgIcon is-" + severity);
            element.innerHTML = ICONS[severity];
            return element;
        },

        // Liczby komunikatów wg typu: { error, warning, info }
        count: function (messages) {
            var counts = { error: 0, warning: 0, info: 0 };
            messages.forEach(function (message) {
                counts[keyOf(rankOf(message))]++;
            });
            return counts;
        },

        // options: { getText(key, args), showDate }
        render: function (container, messages, options) {
            var that = this;
            var dateFormat = DateFormat.getDateInstance({ pattern: "EEE, d MMM yyyy" });
            container.innerHTML = "";

            if (!messages.length) {
                container.appendChild(create("div", "zwbRczMsgEmpty", options.getText("msgNone")));
                return;
            }

            var sorted = sortMessages(messages);
            GROUPS.forEach(function (group) {
                var items = sorted.filter(function (message) {
                    return rankOf(message) === group.rank;
                });
                if (!items.length) {
                    return;
                }
                var section = create("section", "zwbRczMsgGroup is-" + group.key);
                var header = create("div", "zwbRczMsgGroupHead");
                header.appendChild(that.icon(group.key));
                header.appendChild(create("span", "zwbRczMsgGroupTitle", options.getText(group.textKey)));
                header.appendChild(create("span", "zwbRczMsgGroupCount", String(items.length)));
                section.appendChild(header);

                items.forEach(function (message) {
                    var item = create("div", "zwbRczMsgItem is-" + group.key);
                    item.appendChild(that.icon(group.key));
                    var body = create("div", "zwbRczMsgBody");
                    body.appendChild(create("div", "zwbRczMsgText", message.Tekom || ""));
                    var meta = [];
                    if (options.showDate && message.Dakom) {
                        meta.push(dateFormat.format(toDate(message.Dakom)));
                    }
                    if (message.BeginTime || message.EndTime) {
                        meta.push((message.BeginTime || "") + " – " + (message.EndTime || ""));
                    }
                    if (message.Msgid || message.Msgno) {
                        meta.push(String(message.Msgid || "").trim() + " " + String(message.Msgno || "").trim());
                    }
                    if (meta.length) {
                        body.appendChild(create("div", "zwbRczMsgMeta", meta.join("  ·  ")));
                    }
                    item.appendChild(body);
                    section.appendChild(item);
                });
                container.appendChild(section);
            });
        }
    };
});
