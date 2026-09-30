
// ISO-8601 week number of a date.
function isoWeek(d) {
    var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    var day = t.getUTCDay() || 7;
    t.setUTCDate(t.getUTCDate() + 4 - day);
    var start = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
    return Math.ceil(((t - start) / 86400000 + 1) / 7);
}

// 0 = Monday … 6 = Sunday.
function mondayIndex(d) {
    return (d.getDay() + 6) % 7;
}

// 1 on January 1st … 365 (366) on December 31st.
function dayOfYear(d) {
    var start = new Date(d.getFullYear(), 0, 0);
    return Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - start) / 86400000);
}
