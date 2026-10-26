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

    var LABELS = {
        msgColDate: "Data",
        msgColText: "Komunikat",
        msgColTime: "Godziny",
        msgColNumber: "Nr komunikatu"
    };

    function label(options, key) {
        var text = options.getText(key);
        return text && text !== key ? text : LABELS[key];
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
            var dayFormat = DateFormat.getDateInstance({ pattern: "dd.MM.yyyy" });
            var weekdayFormat = DateFormat.getDateInstance({ pattern: "EEEE" });
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

                var table = create("div", "zwbRczMsgTable" + (options.showDate ? " has-date" : ""));
                var head = create("div", "zwbRczMsgRow is-head");
                head.appendChild(create("span", "zwbRczMsgCellIcon"));
                if (options.showDate) {
                    head.appendChild(create("span", "zwbRczMsgCellDate", label(options, "msgColDate")));
                }
                head.appendChild(create("span", "zwbRczMsgCellText", label(options, "msgColText")));
                head.appendChild(create("span", "zwbRczMsgCellTime", label(options, "msgColTime")));
                head.appendChild(create("span", "zwbRczMsgCellNo", label(options, "msgColNumber")));
                table.appendChild(head);

                items.forEach(function (message) {
                    var row = create("div", "zwbRczMsgRow is-" + group.key);
                    var iconCell = create("span", "zwbRczMsgCellIcon");
                    iconCell.appendChild(that.icon(group.key));
                    row.appendChild(iconCell);

                    if (options.showDate) {
                        var dateCell = create("span", "zwbRczMsgCellDate");
                        if (message.Dakom) {
                            var date = toDate(message.Dakom);
                            var weekend = date.getDay() === 0 ? " is-sunday" : date.getDay() === 6 ? " is-saturday" : "";
                            dateCell.appendChild(create("span", "zwbRczMsgDay" + weekend, dayFormat.format(date)));
                            dateCell.appendChild(create("span", "zwbRczMsgWeekday" + weekend, weekdayFormat.format(date)));
                        }
                        row.appendChild(dateCell);
                    }

                    row.appendChild(create("span", "zwbRczMsgCellText", message.Tekom || ""));

                    var time = message.BeginTime || message.EndTime
                        ? (message.BeginTime || "") + "–" + (message.EndTime || "") : "";
                    row.appendChild(create("span", "zwbRczMsgCellTime", time));

                    var noCell = create("span", "zwbRczMsgCellNo");
                    var msgid = String(message.Msgid || "").trim();
                    var msgno = String(message.Msgno || "").trim();
                    if (msgid || msgno) {
                        var chip = create("span", "zwbRczMsgNo");
                        chip.title = msgid + " " + msgno;
                        chip.appendChild(create("span", "zwbRczMsgNoNumber", msgno));
                        chip.appendChild(create("span", "zwbRczMsgNoClass", msgid));
                        noCell.appendChild(chip);
                    }
                    row.appendChild(noCell);
                    table.appendChild(row);
                });
                section.appendChild(table);
                container.appendChild(section);
            });
        }
    };
});
