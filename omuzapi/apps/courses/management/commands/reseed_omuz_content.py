"""Fixture content for management command reseed_omuz (local/staging data generation)."""

from decimal import Decimal

YT = "https://www.youtube.com/watch?v={}"

# Unsplash stills (no API key; stable CDN URLs)
IMG = {
    "web": "https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=1200&q=80",
    "python": "https://images.unsplash.com/photo-1526379095098-d400fd0bf935?w=1200&q=80",
    "excel": "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&q=80",
    "marketing": "https://images.unsplash.com/photo-1533750349088-cd871a92f312?w=1200&q=80",
    "english": "https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=1200&q=80",
    "figma": "https://images.unsplash.com/photo-1561070791-2526d30994b5?w=1200&q=80",
    "security": "https://images.unsplash.com/photo-1563986768609-322da13575f3?w=1200&q=80",
    "agile": "https://images.unsplash.com/photo-1552664730-d307ca884978?w=1200&q=80",
    "data": "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&q=80",
    "ai": "https://images.unsplash.com/photo-1677442136019-21780ecad995?w=1200&q=80",
}

PREVIEW = {
    "web": YT.format("UB1O30fR-EE"),
    "python": YT.format("kqtD5dpn9C8"),
    "excel": YT.format("Vl0H-qTcmOg"),
    "marketing": YT.format("nUubjPL8jfo"),
    "english": YT.format("Hp9gwnNvZ4Y"),
    "figma": YT.format("FTFaQWZBqQ8"),
    "security": YT.format("inWWhr5tnEA"),
    "agile": YT.format("502G7Kl7RFU"),
    "data": YT.format("r-uOL6NUw5A"),
    "ai": YT.format("ad79nYk2keg"),
}


def _q(text: str, correct: str, wrong: tuple[str, ...]):
    answers = [(correct, True)] + [(w, False) for w in wrong]
    return text, answers


def _category_rows():
    return [
        ("Technology", "💻"),
        ("Business & Career", "📊"),
        ("Languages", "🌍"),
        ("Data & AI", "📈"),
    ]


def _course_blueprints():
    """Each: key, title, description, category_name, price, image_key, preview_key, modules."""
    return [
        (
            "web",
            "Modern Web Development",
            "HTML, CSS, and JavaScript fundamentals for building responsive websites.",
            "Technology",
            Decimal("59.00"),
            "web",
            "web",
            [
                (
                    "How the web works",
                    [
                        (
                            "Clients, servers, and HTTP",
                            "Understand how browsers talk to servers and what happens when you open a link.",
                            "UB1O30fR-EE",
                            "Web foundations",
                            [
                                _q(
                                    "What does HTTP stand for?",
                                    "Hypertext Transfer Protocol",
                                    ("Hypertext Transfer Product", "High Text Transfer Protocol", "Host Transfer Protocol"),
                                ),
                                _q(
                                    "Which part usually renders the page you see?",
                                    "The web browser on your device",
                                    ("Only the database server", "The printer", "FTP server"),
                                ),
                            ],
                        ),
                        (
                            "HTML document structure",
                            "Semantic tags, headings, links, and accessible markup.",
                            "UB1O30fR-EE",
                            "HTML structure",
                            [
                                _q(
                                    "Which tag is most appropriate for the main page title shown in search results?",
                                    "<title>",
                                    ("<div>", "<span>", "<strong>"),
                                ),
                                _q(
                                    "What is the purpose of the alt attribute on images?",
                                    "Describe the image for screen readers and when it fails to load",
                                    ("Make images load faster", "Hide images", "Add a border"),
                                ),
                            ],
                        ),
                    ],
                ),
                (
                    "CSS and layout",
                    [
                        (
                            "CSS selectors and the box model",
                            "Margin, padding, border, and how sizing works.",
                            "1PnVor36_40",
                            "CSS basics",
                            [
                                _q(
                                    "In the CSS box model, what is outside the border?",
                                    "Margin",
                                    ("Padding", "Content", "Outline only"),
                                ),
                                _q(
                                    "Which property controls space inside the border around content?",
                                    "padding",
                                    ("margin", "border-radius", "z-index"),
                                ),
                            ],
                        ),
                        (
                            "Flexbox for responsive layouts",
                            "Align and distribute items along rows and columns.",
                            "1PnVor36_40",
                            "Flexbox",
                            [
                                _q(
                                    "Which declaration turns on flex layout for a container?",
                                    "display: flex",
                                    ("display: grid", "float: flex", "position: flex"),
                                ),
                                _q(
                                    "Which property aligns flex items along the cross axis?",
                                    "align-items",
                                    ("justify-content", "flex-flow", "gap-only"),
                                ),
                            ],
                        ),
                    ],
                ),
                (
                    "JavaScript essentials",
                    [
                        (
                            "Variables, types, and operators",
                            "let, const, numbers, strings, and basic expressions.",
                            "W6NZfCO5SIk",
                            "JS variables",
                            [
                                _q(
                                    "Which keyword declares a block-scoped variable that can be reassigned?",
                                    "let",
                                    ("const", "var-only", "def"),
                                ),
                                _q(
                                    "What does typeof null return in JavaScript?",
                                    "object",
                                    ("null", "undefined", "boolean"),
                                ),
                            ],
                        ),
                        (
                            "DOM manipulation and events",
                            "Selecting elements, changing text, and handling clicks.",
                            "W6NZfCO5SIk",
                            "DOM & events",
                            [
                                _q(
                                    "Which method attaches a click listener in modern browsers?",
                                    "addEventListener('click', handler)",
                                    ("onclickHTML only", "listenClick()", "onTap()"),
                                ),
                                _q(
                                    "What does document.querySelector do?",
                                    "Returns the first element matching a CSS selector",
                                    ("Deletes an element", "Loads a script", "Creates a database"),
                                ),
                            ],
                        ),
                    ],
                ),
            ],
        ),
        (
            "python",
            "Python Programming from Zero",
            "Variables, control flow, functions, and files with clear examples.",
            "Technology",
            Decimal("69.00"),
            "python",
            "python",
            [
                (
                    "Python basics",
                    [
                        (
                            "Installing Python and running scripts",
                            "REPL, .py files, and virtual environments overview.",
                            "kqtD5dpn9C8",
                            "Getting started",
                            [
                                _q("What is a common command to run a Python file?", "python main.py", ("run-py", "exec main", "start python")),
                                _q("Which tool isolates project dependencies?", "virtual environment (venv)", ("global pip only", "ZIP archive", "Docker only")),
                            ],
                        ),
                        (
                            "Variables, collections, and loops",
                            "Lists, dicts, for/while, and iteration patterns.",
                            "x7X9w_GIm1s",
                            "Collections & loops",
                            [
                                _q("Which type maps keys to values?", "dict", ("list", "tuple", "set")),
                                _q("What does range(3) iterate over in Python 3?", "0, 1, 2", ("1, 2, 3", "0, 1, 2, 3", "empty")),
                            ],
                        ),
                    ],
                ),
                (
                    "Functions and modules",
                    [
                        (
                            "Defining and calling functions",
                            "Parameters, return values, and scope.",
                            "YYXdXT2l-Gg",
                            "Functions",
                            [
                                _q("How do you define a function in Python?", "def name():", ("function name():", "fn name {}", "func name ->"),
                                ),
                                _q("What keyword returns a value from a function?", "return", ("yield only", "pass", "break")),
                            ],
                        ),
                        (
                            "Imports and standard library",
                            "Organizing code across files; json, pathlib, datetime.",
                            "YYXdXT2l-Gg",
                            "Modules",
                            [
                                _q("Which statement loads another module?", "import module", ("include module", "using module", "require module")),
                                _q("Which module parses JSON strings?", "json", ("xml", "csv", "re")),
                            ],
                        ),
                    ],
                ),
                (
                    "Working with data",
                    [
                        (
                            "Reading and writing text files",
                            "Context managers and encoding.",
                            "rHux0gMZ3Eg",
                            "Files",
                            [
                                _q("Which pattern safely closes a file after use?", "with open(...) as f:", ("open(); close() manual only", "readfile()", "load()")),
                                _q("Default file mode for reading text?", "'r'", ("'w'", "'rb' only", "'x'")),
                            ],
                        ),
                        (
                            "Introduction to Django views",
                            "Request/response cycle in a small app.",
                            "rHux0gMZ3Eg",
                            "Django intro",
                            [
                                _q("In Django, what receives an HTTP request and returns a response?", "View", ("Model only", "Template only", "Middleware only")),
                                _q("Which file maps URLs to views?", "urls.py", ("models.py", "settings.py", "wsgi.py")),
                            ],
                        ),
                    ],
                ),
            ],
        ),
        (
            "excel",
            "Excel & Sheets for Business",
            "Formulas, pivot tables, and charts for everyday reporting.",
            "Business & Career",
            Decimal("49.00"),
            "excel",
            "excel",
            [
                (
                    "Spreadsheet foundations",
                    [
                        (
                            "Rows, columns, and cell references",
                            "Relative vs absolute references.",
                            "Vl0H-qTcmOg",
                            "References",
                            [
                                _q("Which reference stays fixed when you copy a formula?", "$A$1 style (absolute)", ("A1 relative only", "Sheet1 only", "R1C1 disabled")),
                                _q("What does SUM(A1:A10) do?", "Adds numeric values in that range", ("Counts text", "Averages booleans", "Deletes rows")),
                            ],
                        ),
                        (
                            "Common functions: IF, VLOOKUP/XLOOKUP",
                            "Logical tests and lookups.",
                            "Vl0H-qTcmOg",
                            "Functions",
                            [
                                _q("Which function returns one value if a condition is true and another if false?", "IF", ("SUM", "LEN", "TRIM")),
                                _q("Modern Excel replacement for VLOOKUP in many cases?", "XLOOKUP (where available)", ("CONCAT only", "PIVOT only", "RAND")),
                            ],
                        ),
                    ],
                ),
                (
                    "Analysis and charts",
                    [
                        (
                            "Pivot tables",
                            "Summarize large tables quickly.",
                            "Vl0H-qTcmOg",
                            "Pivot tables",
                            [
                                _q("What is a pivot table mainly used for?", "Summarizing and grouping data", ("Writing macros only", "Encrypting sheets", "Printing")),
                                _q("Typical pivot table output includes?", "Aggregated totals by categories", ("Only raw cells", "Only images", "Only fonts")),
                            ],
                        ),
                        (
                            "Charts and storytelling",
                            "Choosing chart types for your message.",
                            "Vl0H-qTcmOg",
                            "Charts",
                            [
                                _q("Best for trends over time?", "Line or column chart", ("Pie for time series", "Scatter for single category", "Doughnut for stock")),
                                _q("Chart title should usually...", "State the insight or metric clearly", ("Be empty", "Use random words", "Hide units")),
                            ],
                        ),
                    ],
                ),
                (
                    "Collaboration and delivery",
                    [
                        (
                            "Sharing, links, and permissions",
                            "Who can view or edit shared files.",
                            "Vl0H-qTcmOg",
                            "Sharing",
                            [
                                _q("Before sharing externally, you should...", "Check sensitivity and access level", ("Share admin passwords", "Disable versioning", "Remove all formulas")),
                                _q("Comment threads help teams...", "Discuss cells without losing context", ("Replace email entirely", "Delete data", "Hide pivot tables")),
                            ],
                        ),
                        (
                            "Export to PDF and images",
                            "Clean handoff for reports and decks.",
                            "Vl0H-qTcmOg",
                            "Export",
                            [
                                _q("PDF export is useful when...", "You need a fixed layout for readers", ("You need live formulas", "You must edit cells", "You need macros")),
                                _q("High-resolution images help when...", "Slides or docs are shown on large screens", ("You delete charts", "You remove axes", "You skip labels")),
                            ],
                        ),
                    ],
                ),
            ],
        ),
        (
            "marketing",
            "Digital Marketing Fundamentals",
            "Funnel, channels, metrics, and ethical targeting.",
            "Business & Career",
            Decimal("54.00"),
            "marketing",
            "marketing",
            [
                (
                    "Strategy",
                    [
                        (
                            "Audience and value proposition",
                            "Who you serve and why they choose you.",
                            "nUubjPL8jfo",
                            "Positioning",
                            [
                                _q("A clear value proposition should explain...", "Who it helps and what outcome they get", ("Only your logo", "Server uptime", "Office address")),
                                _q("A marketing funnel typically moves people from...", "Awareness toward conversion", ("Payroll to HR", "Code to compile", "DNS to DHCP")),
                            ],
                        ),
                        (
                            "Channels overview",
                            "Search, social, email, and content.",
                            "nUubjPL8jfo",
                            "Channels",
                            [
                                _q("Organic search traffic often relates to...", "SEO and content relevance", ("Only paid ads", "Printer settings", "BIOS")),
                                _q("Email marketing works best when...", "Lists are permission-based and segmented", ("You buy random lists", "You never test subject lines", "You hide unsubscribe")),
                            ],
                        ),
                    ],
                ),
                (
                    "Measurement",
                    [
                        (
                            "KPIs and attribution basics",
                            "CTR, CPA, ROAS in context.",
                            "nUubjPL8jfo",
                            "KPIs",
                            [
                                _q("CTR usually means...", "Clicks divided by impressions", ("Cost per click only", "Revenue only", "Bounce rate only")),
                                _q("Attribution models help you...", "Understand which touchpoints contributed to conversions", ("Design logos", "Write SQL", "Host DNS")),
                            ],
                        ),
                        (
                            "Experiments and A/B tests",
                            "Hypothesis, sample size, and ethics.",
                            "nUubjPL8jfo",
                            "Testing",
                            [
                                _q("An A/B test changes...", "One primary variable between variants", ("Everything at once", "Only the price illegally", "User passwords")),
                                _q("Why run tests?", "Learn what improves outcomes with evidence", ("Guess randomly", "Avoid analytics", "Increase load time")),
                            ],
                        ),
                    ],
                ),
                (
                    "Content and brand",
                    [
                        (
                            "Content pillars and calendars",
                            "Planning useful, consistent publishing.",
                            "nUubjPL8jfo",
                            "Content planning",
                            [
                                _q("A content pillar is...", "A core theme your content repeatedly supports", ("A random post", "Only paid ads", "A server rack")),
                                _q("Editorial calendars help...", "Coordinate timing, owners, and channels", ("Remove deadlines", "Ban SEO", "Delete analytics")),
                            ],
                        ),
                        (
                            "Brand voice and guidelines",
                            "Tone, visuals, and approvals.",
                            "nUubjPL8jfo",
                            "Brand",
                            [
                                _q("Brand guidelines reduce...", "Inconsistent messaging and design drift", ("All creativity", "All metrics", "All email")),
                                _q("Voice describes...", "How your brand sounds in writing", ("Only logo colors", "Only server region", "Only pricing")),
                            ],
                        ),
                    ],
                ),
            ],
        ),
        (
            "english",
            "English for Tech Workplaces",
            "Meetings, emails, and clear explanations for hybrid teams.",
            "Languages",
            Decimal("0.00"),
            "english",
            "english",
            [
                (
                    "Communication basics",
                    [
                        (
                            "Professional email structure",
                            "Subject lines, greetings, and calls to action.",
                            "Hp9gwnNvZ4Y",
                            "Email",
                            [
                                _q("A good subject line should be...", "Specific and concise", ("Empty", "ALL CAPS ALWAYS", "A random emoji only")),
                                _q("Closing politely before your name, you might write...", "Best regards / Kind regards", ("Yo,", "See ya", "Bye bye bye")),
                            ],
                        ),
                        (
                            "Stand-up and status updates",
                            "Yesterday, today, blockers pattern.",
                            "Hp9gwnNvZ4Y",
                            "Stand-ups",
                            [
                                _q("A common stand-up format includes...", "What you did, what you will do, blockers", ("Salary discussion", "Annual review", "Budget approval")),
                                _q("Blockers are...", "Issues stopping progress that may need help", ("Completed tasks", "Coffee types", "Git tags")),
                            ],
                        ),
                    ],
                ),
                (
                    "Clarity under pressure",
                    [
                        (
                            "Explaining technical issues simply",
                            "Audience-aware language.",
                            "Hp9gwnNvZ4Y",
                            "Plain English",
                            [
                                _q("When talking to non-engineers, prefer...", "Concrete outcomes and simple terms", ("Raw stack traces only", "Acronyms without definitions", "Silence")),
                                _q("Confirming understanding is helped by...", "Short summaries and questions", ("Long monologues", "Avoiding questions", "Jargon only")),
                            ],
                        ),
                        (
                            "Writing ticket descriptions",
                            "Steps to reproduce and expected vs actual.",
                            "Hp9gwnNvZ4Y",
                            "Tickets",
                            [
                                _q("A strong bug report usually includes...", "Steps to reproduce and expected behavior", ("Only 'it broke'", "No version info", "Screenshots only with no text")),
                                _q("Expected vs actual means...", "What should happen vs what happened", ("Two colors", "Two servers", "Two salaries")),
                            ],
                        ),
                    ],
                ),
                (
                    "Meetings and documentation",
                    [
                        (
                            "Agendas and meeting notes",
                            "Decisions, owners, and dates.",
                            "Hp9gwnNvZ4Y",
                            "Meetings",
                            [
                                _q("A helpful agenda includes...", "Goals, topics, and time boxes", ("Only jokes", "Blank page", "Passwords")),
                                _q("Meeting notes should capture...", "Decisions and action items with owners", ("Only typos", "Private salaries", "Unrelated links")),
                            ],
                        ),
                        (
                            "Writing clear documentation",
                            "Structure, screenshots, and maintenance.",
                            "Hp9gwnNvZ4Y",
                            "Docs",
                            [
                                _q("Good docs start with...", "Purpose and audience", ("Random APIs", "No headings", "Only emojis")),
                                _q("When procedures change, docs should...", "Be updated or deprecated explicitly", ("Stay wrong forever", "Be deleted silently", "Move to chat only")),
                            ],
                        ),
                    ],
                ),
            ],
        ),
        (
            "figma",
            "UI Design Foundations in Figma",
            "Frames, components, auto layout, and handoff basics.",
            "Technology",
            Decimal("64.00"),
            "figma",
            "figma",
            [
                (
                    "Figma workspace",
                    [
                        (
                            "Frames and grids",
                            "Artboards, layout grids, and constraints.",
                            "FTFaQWZBqQ8",
                            "Frames",
                            [
                                _q("In Figma, what is a Frame?", "A container for design with its own dimensions", ("Only a bitmap", "A code file", "A font")),
                                _q("Layout grids help with...", "Alignment and consistent spacing", ("Sound mixing", "Database indexes", "DNS")),
                            ],
                        ),
                        (
                            "Typography and color styles",
                            "Reusable text and fill styles.",
                            "FTFaQWZBqQ8",
                            "Styles",
                            [
                                _q("Text styles in design systems help...", "Keep typography consistent across screens", ("Increase random fonts", "Remove hierarchy", "Disable exports")),
                                _q("Color styles are useful for...", "Theming and quick global updates", ("Hiding layers", "Deleting components", "Locking files")),
                            ],
                        ),
                    ],
                ),
                (
                    "Components and systems",
                    [
                        (
                            "Components and variants",
                            "Buttons with states.",
                            "FTFaQWZBqQ8",
                            "Components",
                            [
                                _q("A component is...", "A reusable UI element you can instance", ("A single raster image", "A video codec", "A SQL table")),
                                _q("Variants often represent...", "Different states like default, hover, disabled", ("Different programming languages", "Different offices", "Random colors")),
                            ],
                        ),
                        (
                            "Auto layout",
                            "Responsive spacing between items.",
                            "FTFaQWZBqQ8",
                            "Auto layout",
                            [
                                _q("Auto layout primarily controls...", "Spacing and alignment of child objects", ("3D rotation", "Audio levels", "Server ports")),
                                _q("Padding in auto layout affects...", "Space inside the frame around children", ("Export file size only", "Git history", "DNS TTL")),
                            ],
                        ),
                    ],
                ),
                (
                    "Handoff to development",
                    [
                        (
                            "Inspect and export assets",
                            "Correct scales and formats.",
                            "FTFaQWZBqQ8",
                            "Inspect",
                            [
                                _q("Inspect mode helps developers see...", "Spacing, colors, and typography values", ("Only file names", "Git commits", "DNS records")),
                                _q("Exporting @2x assets is for...", "Sharper bitmaps on high-DPI screens", ("Smaller HTML", "Faster DNS", "Database indexes")),
                            ],
                        ),
                        (
                            "Design tokens mindset",
                            "Naming and consistency for engineering.",
                            "FTFaQWZBqQ8",
                            "Tokens",
                            [
                                _q("Design tokens often represent...", "Reusable decisions like color and radius", ("Random layers", "Server ports", "SQL keys")),
                                _q("Shared naming between design and code...", "Reduces mismatch in implementation", ("Is never useful", "Replaces testing", "Removes QA")),
                            ],
                        ),
                    ],
                ),
            ],
        ),
        (
            "security",
            "Cybersecurity Awareness",
            "Passwords, phishing, MFA, and safe habits for everyone.",
            "Technology",
            Decimal("0.00"),
            "security",
            "security",
            [
                (
                    "Threats and habits",
                    [
                        (
                            "Phishing and social engineering",
                            "Recognizing suspicious messages.",
                            "inWWhr5tnEA",
                            "Phishing",
                            [
                                _q("A common phishing sign is...", "Urgent requests for passwords or codes", ("Slow email delivery", "Calendar invites only", "Spell-checked corporate mail")),
                                _q("If unsure about a link, you should...", "Verify through an official channel or type the URL", ("Click quickly", "Disable antivirus", "Share MFA codes")),
                            ],
                        ),
                        (
                            "Passwords and password managers",
                            "Length, uniqueness, and storage.",
                            "inWWhr5tnEA",
                            "Passwords",
                            [
                                _q("Strong passwords are usually...", "Long, unique per site, and not guessable", ("Short and reused", "Your birthday everywhere", "admin123")),
                                _q("Password managers help by...", "Generating and storing unique secrets", ("Posting passwords in chat", "Disabling MFA", "Sharing accounts")),
                            ],
                        ),
                    ],
                ),
                (
                    "Protecting accounts",
                    [
                        (
                            "Multi-factor authentication (MFA)",
                            "Something you know and something you have.",
                            "inWWhr5tnEA",
                            "MFA",
                            [
                                _q("MFA adds...", "An extra factor beyond the password", ("Only a longer password", "Nothing useful", "Public Wi‑Fi")),
                                _q("An authenticator app is often...", "A second factor on your phone", ("A replacement for HTTPS", "A type of firewall", "A backup tape")),
                            ],
                        ),
                        (
                            "Updates and backups",
                            "Patching and recovery.",
                            "inWWhr5tnEA",
                            "Updates",
                            [
                                _q("Software updates often include...", "Security fixes", ("Only new icons", "Slower performance on purpose", "Removed encryption")),
                                _q("Backups help you...", "Recover data after loss or ransomware", ("Increase attack surface", "Avoid MFA", "Share passwords")),
                            ],
                        ),
                    ],
                ),
                (
                    "Device and travel hygiene",
                    [
                        (
                            "Public Wi‑Fi and VPN basics",
                            "Risks and safer patterns.",
                            "inWWhr5tnEA",
                            "Wi‑Fi",
                            [
                                _q("Untrusted public Wi‑Fi can enable...", "Traffic interception or rogue hotspots", ("Stronger passwords automatically", "Free MFA", "Encrypted backups only")),
                                _q("A VPN can help by...", "Encrypting traffic to a trusted endpoint", ("Replacing MFA", "Deleting phishing", "Guaranteeing speed")),
                            ],
                        ),
                        (
                            "Lost devices",
                            "Remote lock and reporting.",
                            "inWWhr5tnEA",
                            "Devices",
                            [
                                _q("Full-disk encryption helps if...", "A laptop is lost or stolen", ("You forgot Wi‑Fi password", "You need faster CPU", "You export PDF")),
                                _q("You should report lost work devices because...", "Credentials or data may be at risk", ("It is optional always", "IT does not care", "It fixes DNS")),
                            ],
                        ),
                    ],
                ),
            ],
        ),
        (
            "agile",
            "Agile & Scrum Essentials",
            "Roles, events, and backlog practices for product teams.",
            "Business & Career",
            Decimal("44.00"),
            "agile",
            "agile",
            [
                (
                    "Scrum framework",
                    [
                        (
                            "Roles: PO, Scrum Master, Developers",
                            "Accountabilities in the team.",
                            "502G7Kl7RFU",
                            "Roles",
                            [
                                _q("Who owns prioritization of the backlog in Scrum?", "Product Owner", ("Scrum Master only", "CEO only", "Intern only")),
                                _q("Developers in Scrum are responsible for...", "Delivering a usable increment each Sprint", ("Only meetings", "Sales targets", "Payroll")),
                            ],
                        ),
                        (
                            "Sprint Planning and Daily Scrum",
                            "Committing to a Sprint Goal.",
                            "502G7Kl7RFU",
                            "Events",
                            [
                                _q("The Daily Scrum is for...", "Developers to inspect progress toward the Sprint Goal", ("Annual reviews", "Budget approval", "Hiring only")),
                                _q("Sprint Planning answers what?", "What can be done this Sprint and how", ("Company picnic date", "Office paint color", "Stock price")),
                            ],
                        ),
                    ],
                ),
                (
                    "Backlog quality",
                    [
                        (
                            "User stories and acceptance criteria",
                            "Clear, testable outcomes.",
                            "502G7Kl7RFU",
                            "Stories",
                            [
                                _q("Good acceptance criteria are...", "Specific and testable", ("Vague", "Unlimited scope", "Only technical jargon")),
                                _q("A user story often follows...", "As a … I want … so that …", ("Once upon a time", "SELECT * FROM", "TODO: fix later")),
                            ],
                        ),
                        (
                            "Definition of Done",
                            "Shared quality bar.",
                            "502G7Kl7RFU",
                            "DoD",
                            [
                                _q("Definition of Done exists to...", "Align on when work is truly complete", ("Delay releases", "Skip testing", "Hide bugs")),
                                _q("DoD typically includes...", "Quality practices like tests and reviews where applicable", ("Only design", "Only sales slides", "Nothing")),
                            ],
                        ),
                    ],
                ),
                (
                    "Improvement",
                    [
                        (
                            "Sprint Review and stakeholder feedback",
                            "Inspect the increment together.",
                            "502G7Kl7RFU",
                            "Review",
                            [
                                _q("Sprint Review focuses on...", "The increment and feedback toward the Product Goal", ("Individual blame", "HR policies", "Payroll")),
                                _q("Stakeholder feedback should...", "Inform future backlog ordering", ("Replace the Product Owner", "Delete the backlog", "Skip testing")),
                            ],
                        ),
                        (
                            "Retrospectives",
                            "Process improvements for the team.",
                            "502G7Kl7RFU",
                            "Retro",
                            [
                                _q("A retrospective is primarily for...", "How the team works together", ("Blaming one person", "Budget planning", "Sales quotas")),
                                _q("Good retro outcomes include...", "One or two actionable improvements", ("No follow-up", "Unlimited action items", "Secrets")),
                            ],
                        ),
                    ],
                ),
            ],
        ),
        (
            "data",
            "Data Analysis Basics",
            "Cleaning, visualization, and asking better questions of data.",
            "Data & AI",
            Decimal("72.00"),
            "data",
            "data",
            [
                (
                    "Data hygiene",
                    [
                        (
                            "Types of data and measurement",
                            "Nominal, ordinal, interval, ratio intuition.",
                            "r-uOL6NUw5A",
                            "Data types",
                            [
                                _q("Which is an example of categorical (nominal) data?", "Country codes without order", ("Temperature in °C", "Annual revenue", "Time to complete")),
                                _q("Missing values should be...", "Handled explicitly (impute, exclude, or flag)", ("Ignored always", "Replaced with max always", "Deleted silently without rules")),
                            ],
                        ),
                        (
                            "Cleaning checklist",
                            "Duplicates, outliers, and formats.",
                            "r-uOL6NUw5A",
                            "Cleaning",
                            [
                                _q("Duplicate rows can...", "Skew counts and sums", ("Improve accuracy automatically", "Fix DNS", "Encrypt data")),
                                _q("Standardizing date formats helps...", "Parsing and time-based analysis", ("Increasing entropy", "Removing charts", "Disabling SQL")),
                            ],
                        ),
                    ],
                ),
                (
                    "Visualization",
                    [
                        (
                            "Choosing charts honestly",
                            "Bar vs line vs scatter.",
                            "r-uOL6NUw5A",
                            "Charts",
                            [
                                _q("Truncated y-axis on a bar chart can...", "Misrepresent differences", ("Always be neutral", "Improve honesty", "Remove labels")),
                                _q("Scatter plots are useful for...", "Relationships between two numeric variables", ("Hierarchical budgets", "Org charts only", "DNS records")),
                            ],
                        ),
                        (
                            "Summary statistics",
                            "Mean vs median with skew.",
                            "r-uOL6NUw5A",
                            "Statistics",
                            [
                                _q("With heavy outliers, which center measure is often safer?", "Median", ("Mean always", "Mode only", "Max only")),
                                _q("A distribution is right-skewed if...", "The tail extends toward higher values", ("It is symmetric", "It has no values", "It is a pie chart")),
                            ],
                        ),
                    ],
                ),
                (
                    "From insight to action",
                    [
                        (
                            "Asking the right question",
                            "Problem framing before charts.",
                            "r-uOL6NUw5A",
                            "Questions",
                            [
                                _q("A good analytics question often starts with...", "A decision you need to make", ("The prettiest chart", "The longest SQL", "A random KPI")),
                                _q("Scope creep in analysis means...", "The question keeps expanding without a decision", ("Better dashboards", "Faster ETL", "Cleaner DNS")),
                            ],
                        ),
                        (
                            "Communicating results",
                            "Headline, chart, caveats.",
                            "r-uOL6NUw5A",
                            "Storytelling",
                            [
                                _q("You should mention caveats when...", "Data quality or sample limits affect conclusions", ("Never", "Only in footnotes nobody reads", "Only verbally")),
                                _q("A headline should reflect...", "The main takeaway supported by the data", ("Your favorite color", "Office politics", "Stock tips")),
                            ],
                        ),
                    ],
                ),
            ],
        ),
        (
            "ai",
            "AI Literacy for Professionals",
            "What models can and cannot do, prompts, and responsible use.",
            "Data & AI",
            Decimal("79.00"),
            "ai",
            "ai",
            [
                (
                    "Concepts",
                    [
                        (
                            "What is machine learning?",
                            "Learning patterns from data vs hand-coded rules.",
                            "ad79nYk2keg",
                            "ML basics",
                            [
                                _q("Supervised learning uses...", "Labeled examples to learn inputs→outputs", ("No data", "Only random noise", "DNS logs only")),
                                _q("A model that memorizes training data may...", "Generalize poorly to new data", ("Always be best", "Never need validation", "Fix phishing")),
                            ],
                        ),
                        (
                            "Large language models (LLM) basics",
                            "Probabilistic text, not a database of facts.",
                            "4RixMPF4xis",
                            "LLMs",
                            [
                                _q("LLMs generate text by...", "Predicting likely next tokens", ("Looking up only verified facts", "Running SQL only", "Rendering 3D")),
                                _q("When accuracy matters, you should...", "Verify critical facts from trusted sources", ("Trust blindly", "Disable citations", "Skip review")),
                            ],
                        ),
                    ],
                ),
                (
                    "Practice",
                    [
                        (
                            "Prompting for clarity",
                            "Role, context, constraints, output format.",
                            "4RixMPF4xis",
                            "Prompting",
                            [
                                _q("Clear prompts often specify...", "Goal, audience, and format", ("Only one vague word", "Random emojis", "No context")),
                                _q("Asking for step-by-step reasoning can...", "Improve transparency (when appropriate)", ("Guarantee truth", "Replace domain expertise", "Remove safety policies")),
                            ],
                        ),
                        (
                            "Responsible use",
                            "Privacy, bias, and human oversight.",
                            "4RixMPF4xis",
                            "Responsibility",
                            [
                                _q("Personally identifiable information in prompts should be...", "Minimized or handled per policy", ("Maximized", "Sold", "Ignored")),
                                _q("Human oversight is important because...", "Models can be wrong or biased", ("Models are always perfect", "Humans are illegal", "Oversight is optional always")),
                            ],
                        ),
                    ],
                ),
                (
                    "Workflow in real teams",
                    [
                        (
                            "When to use AI assistants",
                            "Drafting, brainstorming, and code help.",
                            "4RixMPF4xis",
                            "Workflow",
                            [
                                _q("A sensible use is...", "Drafting an outline you then verify and edit", ("Publishing unreviewed medical advice", "Sharing secrets", "Skipping code review")),
                                _q("You should still test code because...", "Models can hallucinate APIs or logic", ("Tests are illegal", "CI is optional", "Lint fixes everything")),
                            ],
                        ),
                        (
                            "Documentation and knowledge bases",
                            "Grounding answers on internal sources.",
                            "4RixMPF4xis",
                            "Grounding",
                            [
                                _q("Retrieval-augmented patterns try to...", "Ground answers in trusted documents", ("Remove all sources", "Guess URLs", "Disable logging")),
                                _q("Stale internal docs can cause...", "Confident wrong answers if trusted blindly", ("Better latency", "Perfect accuracy", "Automatic compliance")),
                            ],
                        ),
                    ],
                ),
            ],
        ),
    ]


def build_courses_payload():
    """Return list of dicts ready for ORM creation."""
    out = []
    for row in _course_blueprints():
        _, title, desc, cat, price, img_k, prev_k, modules_raw = row
        modules_out = []
        for mod_title, lessons in modules_raw:
            lessons_out = []
            for ord_i, (ltitle, ldesc, vid_id, qz_title, questions) in enumerate(lessons, start=1):
                # First lesson in each module: video-only completion (no quiz), like real catalogs.
                if ord_i == 1:
                    lessons_out.append(
                        {
                            "title": ltitle,
                            "description": ldesc,
                            "video_url": YT.format(vid_id),
                            "order": ord_i,
                            "quiz_title": None,
                            "questions": None,
                        }
                    )
                else:
                    lessons_out.append(
                        {
                            "title": ltitle,
                            "description": ldesc,
                            "video_url": YT.format(vid_id),
                            "order": ord_i,
                            "quiz_title": qz_title,
                            "questions": [
                                {"text": qt, "answers": [{"text": a, "is_correct": c} for a, c in ans]}
                                for qt, ans in questions
                            ],
                        }
                    )
            modules_out.append({"title": mod_title, "lessons": lessons_out})
        out.append(
            {
                "title": title,
                "description": desc,
                "category": cat,
                "image": IMG[img_k],
                "preview_video_url": PREVIEW[prev_k],
                "price": price,
                "modules": modules_out,
            }
        )
    return out
