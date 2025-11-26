const fixedDay = new Date(Date.UTC(1986, 3, 26));

function getOffsetMinutes(tz) {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit"
  });

  const parts = dtf.formatToParts(fixedDay);
  const get = type => parseInt(parts.find(p => p.type === type).value, 10);

  const y = get("year");
  const m = get("month");
  const d = get("day");
  const h = get("hour");
  const min = get("minute");
  const s = get("second");

  const tzUtcMs = Date.UTC(y, m - 1, d, h, min, s);

  const origUtcMs = fixedDay.getTime() - (fixedDay.getTime() % 1000);

  const offsetMinutes = (tzUtcMs - origUtcMs) / 60000;

  return Math.round(offsetMinutes) % 1440;
}

console.log(getOffsetMinutes("Zulu"));
console.log(getOffsetMinutes(process.env.BASE_TEST_TZ_NAME));
console.log(getOffsetMinutes('another/weirdtz'));

try {
  getOffsetMinutes("suredont/exist");
} catch (e) {
  console.log(e);
}
