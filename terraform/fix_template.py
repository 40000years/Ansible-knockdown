import re

with open("dashboard_template.html", "r", encoding="utf-8") as f:
    text = f.read()

# Fix preserveAspectRatio newline
text = re.sub(r"preserveAspectRatio: 'xMidYMid\s+meet'", r"preserveAspectRatio: 'xMidYMid meet'", text)

# Fix filter width height newline
text = re.sub(r"height: '220%'\s+\}, defs\);", r"height: '220%' }, defs);", text)

# Fix tooltip template literals (some strings got hard-wrapped in backticks, which is fine, but let's fix single quotes)
text = text.replace("'stroke-width': '1.1',\n                    opacity: '0.55'", "'stroke-width': '1.1', opacity: '0.55'")
text = text.replace("'stroke-width': '1.5', opacity:\n                    '0.75'", "'stroke-width': '1.5', opacity: '0.75'")
text = text.replace("'stroke-width': '1', opacity:\n                    '0.55'", "'stroke-width': '1', opacity: '0.55'")
text = text.replace("stroke:\n                    color", "stroke: color")
text = text.replace("? '' :\n                    's'", "? '' : 's'")

with open("dashboard_template.html", "w", encoding="utf-8") as f:
    f.write(text)
