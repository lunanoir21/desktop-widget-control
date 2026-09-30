
// Countries the place picker can narrow a search to: ISO 3166 code and the name
// in both interface languages. The weather lookup accepts any code, so this list
// only has to be long enough to be useful; "any country" searches everywhere.
var list = [
    { cc: "AL", en: "Albania", tr: "Arnavutluk" },
    { cc: "DZ", en: "Algeria", tr: "Cezayir" },
    { cc: "AR", en: "Argentina", tr: "Arjantin" },
    { cc: "AM", en: "Armenia", tr: "Ermenistan" },
    { cc: "AU", en: "Australia", tr: "Avustralya" },
    { cc: "AT", en: "Austria", tr: "Avusturya" },
    { cc: "AZ", en: "Azerbaijan", tr: "Azerbaycan" },
    { cc: "BH", en: "Bahrain", tr: "Bahreyn" },
    { cc: "BD", en: "Bangladesh", tr: "Bangladeş" },
    { cc: "BY", en: "Belarus", tr: "Belarus" },
    { cc: "BE", en: "Belgium", tr: "Belçika" },
    { cc: "BA", en: "Bosnia and Herzegovina", tr: "Bosna-Hersek" },
    { cc: "BR", en: "Brazil", tr: "Brezilya" },
    { cc: "BG", en: "Bulgaria", tr: "Bulgaristan" },
    { cc: "CA", en: "Canada", tr: "Kanada" },
    { cc: "CL", en: "Chile", tr: "Şili" },
    { cc: "CN", en: "China", tr: "Çin" },
    { cc: "CO", en: "Colombia", tr: "Kolombiya" },
    { cc: "HR", en: "Croatia", tr: "Hırvatistan" },
    { cc: "CY", en: "Cyprus", tr: "Kıbrıs" },
    { cc: "CZ", en: "Czechia", tr: "Çekya" },
    { cc: "DK", en: "Denmark", tr: "Danimarka" },
    { cc: "EG", en: "Egypt", tr: "Mısır" },
    { cc: "EE", en: "Estonia", tr: "Estonya" },
    { cc: "FI", en: "Finland", tr: "Finlandiya" },
    { cc: "FR", en: "France", tr: "Fransa" },
    { cc: "GE", en: "Georgia", tr: "Gürcistan" },
    { cc: "DE", en: "Germany", tr: "Almanya" },
    { cc: "GR", en: "Greece", tr: "Yunanistan" },
    { cc: "HU", en: "Hungary", tr: "Macaristan" },
    { cc: "IS", en: "Iceland", tr: "İzlanda" },
    { cc: "IN", en: "India", tr: "Hindistan" },
    { cc: "ID", en: "Indonesia", tr: "Endonezya" },
    { cc: "IR", en: "Iran", tr: "İran" },
    { cc: "IQ", en: "Iraq", tr: "Irak" },
    { cc: "IE", en: "Ireland", tr: "İrlanda" },
    { cc: "IL", en: "Israel", tr: "İsrail" },
    { cc: "IT", en: "Italy", tr: "İtalya" },
    { cc: "JP", en: "Japan", tr: "Japonya" },
    { cc: "JO", en: "Jordan", tr: "Ürdün" },
    { cc: "KZ", en: "Kazakhstan", tr: "Kazakistan" },
    { cc: "XK", en: "Kosovo", tr: "Kosova" },
    { cc: "KW", en: "Kuwait", tr: "Kuveyt" },
    { cc: "KG", en: "Kyrgyzstan", tr: "Kırgızistan" },
    { cc: "LV", en: "Latvia", tr: "Letonya" },
    { cc: "LB", en: "Lebanon", tr: "Lübnan" },
    { cc: "LY", en: "Libya", tr: "Libya" },
    { cc: "LT", en: "Lithuania", tr: "Litvanya" },
    { cc: "LU", en: "Luxembourg", tr: "Lüksemburg" },
    { cc: "MY", en: "Malaysia", tr: "Malezya" },
    { cc: "MX", en: "Mexico", tr: "Meksika" },
    { cc: "MD", en: "Moldova", tr: "Moldova" },
    { cc: "ME", en: "Montenegro", tr: "Karadağ" },
    { cc: "MA", en: "Morocco", tr: "Fas" },
    { cc: "NL", en: "Netherlands", tr: "Hollanda" },
    { cc: "NZ", en: "New Zealand", tr: "Yeni Zelanda" },
    { cc: "NG", en: "Nigeria", tr: "Nijerya" },
    { cc: "MK", en: "North Macedonia", tr: "Kuzey Makedonya" },
    { cc: "NO", en: "Norway", tr: "Norveç" },
    { cc: "PK", en: "Pakistan", tr: "Pakistan" },
    { cc: "PE", en: "Peru", tr: "Peru" },
    { cc: "PH", en: "Philippines", tr: "Filipinler" },
    { cc: "PL", en: "Poland", tr: "Polonya" },
    { cc: "PT", en: "Portugal", tr: "Portekiz" },
    { cc: "QA", en: "Qatar", tr: "Katar" },
    { cc: "RO", en: "Romania", tr: "Romanya" },
    { cc: "RU", en: "Russia", tr: "Rusya" },
    { cc: "SA", en: "Saudi Arabia", tr: "Suudi Arabistan" },
    { cc: "RS", en: "Serbia", tr: "Sırbistan" },
    { cc: "SG", en: "Singapore", tr: "Singapur" },
    { cc: "SK", en: "Slovakia", tr: "Slovakya" },
    { cc: "SI", en: "Slovenia", tr: "Slovenya" },
    { cc: "ZA", en: "South Africa", tr: "Güney Afrika" },
    { cc: "KR", en: "South Korea", tr: "Güney Kore" },
    { cc: "ES", en: "Spain", tr: "İspanya" },
    { cc: "SE", en: "Sweden", tr: "İsveç" },
    { cc: "CH", en: "Switzerland", tr: "İsviçre" },
    { cc: "SY", en: "Syria", tr: "Suriye" },
    { cc: "TW", en: "Taiwan", tr: "Tayvan" },
    { cc: "TH", en: "Thailand", tr: "Tayland" },
    { cc: "TN", en: "Tunisia", tr: "Tunus" },
    { cc: "TR", en: "Türkiye", tr: "Türkiye" },
    { cc: "UA", en: "Ukraine", tr: "Ukrayna" },
    { cc: "AE", en: "United Arab Emirates", tr: "Birleşik Arap Emirlikleri" },
    { cc: "GB", en: "United Kingdom", tr: "Birleşik Krallık" },
    { cc: "US", en: "United States", tr: "Amerika Birleşik Devletleri" },
    { cc: "UZ", en: "Uzbekistan", tr: "Özbekistan" },
    { cc: "VN", en: "Vietnam", tr: "Vietnam" }
];

function name(entry, lang) {
    return lang === "tr" ? entry.tr : entry.en;
}

// [{ v: code, label: name }] sorted by name in `lang`, for a DSelect; the caller
// puts its own "any country" row first.
function choices(lang) {
    var out = list.map(function (c) { return { v: c.cc, label: name(c, lang) }; });
    out.sort(function (a, b) { return a.label.localeCompare(b.label, lang === "tr" ? "tr" : "en"); });
    return out;
}

function byCode(cc) {
    for (var i = 0; i < list.length; i++)
        if (list[i].cc === cc)
            return list[i];
    return null;
}
