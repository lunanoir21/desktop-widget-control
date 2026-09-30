
// Points along the outline of a rounded rectangle, clockwise from the middle of
// the top edge, about `step` pixels apart. The clock's ring draws its seconds
// by taking a prefix of this list; the last point is the first again, so the
// outline closes.
function roundedRectPoints(w, h, r, step) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    var cx = w / 2;
    var pts = [];

    function line(x1, y1, x2, y2) {
        var n = Math.max(1, Math.ceil(Math.hypot(x2 - x1, y2 - y1) / step));
        for (var i = 0; i < n; i++)
            pts.push({ x: x1 + (x2 - x1) * i / n, y: y1 + (y2 - y1) * i / n });
    }
    function arc(ox, oy, a0, a1) {
        var n = Math.max(1, Math.ceil(r * Math.abs(a1 - a0) / step));
        for (var i = 0; i < n; i++) {
            var a = a0 + (a1 - a0) * i / n;
            pts.push({ x: ox + r * Math.cos(a), y: oy + r * Math.sin(a) });
        }
    }

    line(cx, 0, w - r, 0);
    arc(w - r, r, -Math.PI / 2, 0);
    line(w, r, w, h - r);
    arc(w - r, h - r, 0, Math.PI / 2);
    line(w - r, h, r, h);
    arc(r, h - r, Math.PI / 2, Math.PI);
    line(0, h - r, 0, r);
    arc(r, r, Math.PI, Math.PI * 1.5);
    line(r, 0, cx, 0);
    pts.push({ x: cx, y: 0 });
    return pts;
}

// The first `frac` (0..1) of a list of points.
function prefix(points, frac) {
    var f = Math.max(0, Math.min(1, frac));
    var n = Math.max(2, Math.round(f * (points.length - 1)) + 1);
    return points.slice(0, n);
}
