#include "keyword_napi.h"

#include <algorithm>
#include <cctype>
#include <sstream>

static inline std::string Trim(const std::string &s)
{
    size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start]))) {
        start++;
    }
    size_t end = s.size();
    while (end > start && std::isspace(static_cast<unsigned char>(s[end - 1]))) {
        end--;
    }
    return s.substr(start, end - start);
}

static inline bool StartsWith(const std::string &s, const std::string &prefix)
{
    return s.size() >= prefix.size() && s.compare(0, prefix.size(), prefix) == 0;
}

static std::vector<std::string> SplitLines(const std::string &text)
{
    std::vector<std::string> lines;
    std::string current;
    current.reserve(text.size());

    for (size_t i = 0; i < text.size(); i++) {
        char c = text[i];
        if (c == '\r') {
            continue;
        }
        if (c == '\n') {
            lines.push_back(current);
            current.clear();
            continue;
        }
        current.push_back(c);
    }
    lines.push_back(current);
    return lines;
}

static std::string CollapseSpaces(const std::string &s)
{
    std::string out;
    out.reserve(s.size());
    bool inSpace = false;
    for (char c : s) {
        if (std::isspace(static_cast<unsigned char>(c))) {
            if (!inSpace) {
                out.push_back(' ');
                inSpace = true;
            }
        } else {
            out.push_back(c);
            inSpace = false;
        }
    }
    return Trim(out);
}

static std::string StripMarkdownInline(const std::string &s)
{
    // Minimal inline stripping for plain text:
    // - remove backticks, asterisks, brackets in common patterns
    // - keep link text of [text](url)
    std::string out;
    out.reserve(s.size());

    for (size_t i = 0; i < s.size(); i++) {
        char c = s[i];
        if (c == '`' || c == '*' || c == '_') {
            continue;
        }
        if (c == '[') {
            // copy until ']' as link text, then skip optional (..)
            size_t close = s.find(']', i + 1);
            if (close != std::string::npos) {
                out.append(s.substr(i + 1, close - (i + 1)));
                i = close;
                if (i + 1 < s.size() && s[i + 1] == '(') {
                    size_t endParen = s.find(')', i + 2);
                    if (endParen != std::string::npos) {
                        i = endParen;
                    }
                }
                continue;
            }
        }
        out.push_back(c);
    }

    return CollapseSpaces(out);
}

std::vector<std::string> ExtractKeywords(const std::string &text, int32_t topK)
{
    // Placeholder: keep interface stable; real keyword extraction can be plugged later.
    (void)text;
    (void)topK;
    return {};
}

MarkdownDocument ParseMarkdown(const std::string &markdown)
{
    MarkdownDocument doc;
    const auto lines = SplitLines(markdown);

    bool inCodeBlock = false;
    std::string codeLang;
    std::ostringstream codeBuf;

    auto flushCodeBlock = [&]() {
        MarkdownBlockNode b;
        b.type = "code_block";
        b.language = codeLang;
        b.text = codeBuf.str();
        doc.blocks.push_back(std::move(b));
        codeLang.clear();
        codeBuf.str(std::string());
        codeBuf.clear();
    };

    auto addParagraphIfNotEmpty = [&](const std::string &text) {
        const std::string t = Trim(text);
        if (t.empty()) return;
        MarkdownBlockNode b;
        b.type = "paragraph";
        b.text = t;
        doc.blocks.push_back(std::move(b));
    };

    std::ostringstream paragraphBuf;
    auto flushParagraph = [&]() {
        const std::string para = Trim(paragraphBuf.str());
        if (!para.empty()) {
            MarkdownBlockNode b;
            b.type = "paragraph";
            b.text = para;
            doc.blocks.push_back(std::move(b));
        }
        paragraphBuf.str(std::string());
        paragraphBuf.clear();
    };

    for (size_t i = 0; i < lines.size(); i++) {
        const std::string raw = lines[i];
        const std::string line = raw; // keep indentation for code fence detection
        const std::string trimmed = Trim(line);

        if (StartsWith(trimmed, "```")) {
            if (!inCodeBlock) {
                flushParagraph();
                inCodeBlock = true;
                codeLang = Trim(trimmed.substr(3));
            } else {
                inCodeBlock = false;
                flushCodeBlock();
            }
            continue;
        }

        if (inCodeBlock) {
            codeBuf << raw;
            if (i + 1 < lines.size()) codeBuf << "\n";
            continue;
        }

        if (trimmed.empty()) {
            flushParagraph();
            continue;
        }

        // Divider
        if (trimmed == "---" || trimmed == "***" || trimmed == "___") {
            flushParagraph();
            MarkdownBlockNode b;
            b.type = "divider";
            doc.blocks.push_back(std::move(b));
            continue;
        }

        // Heading
        if (StartsWith(trimmed, "#")) {
            size_t hashes = 0;
            while (hashes < trimmed.size() && trimmed[hashes] == '#') hashes++;
            if (hashes >= 1 && hashes <= 6 && hashes < trimmed.size() && trimmed[hashes] == ' ') {
                flushParagraph();
                MarkdownBlockNode b;
                b.type = "heading";
                b.level = static_cast<int32_t>(hashes);
                b.text = Trim(trimmed.substr(hashes + 1));
                doc.blocks.push_back(std::move(b));
                continue;
            }
        }

        // Quote
        if (StartsWith(trimmed, ">")) {
            flushParagraph();
            MarkdownBlockNode b;
            b.type = "quote";
            std::string q = trimmed.substr(1);
            if (!q.empty() && q[0] == ' ') q.erase(0, 1);
            b.text = q;
            doc.blocks.push_back(std::move(b));
            continue;
        }

        // Checklist
        if (StartsWith(trimmed, "- [")) {
            if (trimmed.size() >= 6 && trimmed[4] == ']' && trimmed[5] == ' ') {
                flushParagraph();
                MarkdownBlockNode b;
                b.type = "checklist_item";
                char c = trimmed[3];
                b.checked = (c == 'x' || c == 'X');
                b.text = Trim(trimmed.substr(6));
                doc.blocks.push_back(std::move(b));
                continue;
            }
        }

        // Bullet list item
        if (StartsWith(trimmed, "- ") || StartsWith(trimmed, "* ")) {
            flushParagraph();
            MarkdownBlockNode b;
            b.type = "bullet_item";
            b.text = Trim(trimmed.substr(2));
            doc.blocks.push_back(std::move(b));
            continue;
        }

        // Ordered list item: "1. xxx"
        {
            size_t j = 0;
            while (j < trimmed.size() && std::isdigit(static_cast<unsigned char>(trimmed[j]))) j++;
            if (j > 0 && j + 1 < trimmed.size() && trimmed[j] == '.' && trimmed[j + 1] == ' ') {
                flushParagraph();
                MarkdownBlockNode b;
                b.type = "ordered_item";
                b.text = Trim(trimmed.substr(j + 2));
                doc.blocks.push_back(std::move(b));
                continue;
            }
        }

        // Paragraph accumulation
        if (paragraphBuf.tellp() > 0) paragraphBuf << "\n";
        paragraphBuf << raw;
    }

    if (inCodeBlock) {
        // If fence not closed, still flush as code block.
        inCodeBlock = false;
        flushCodeBlock();
    }

    flushParagraph();

    // Extraction heuristics
    for (const auto &b : doc.blocks) {
        if (doc.extractedTitle.empty() && b.type == "heading" && b.level == 1) {
            doc.extractedTitle = StripMarkdownInline(b.text);
            continue;
        }
        if (doc.extractedSummary.empty()) {
            if (b.type == "quote") {
                doc.extractedSummary = StripMarkdownInline(b.text);
                continue;
            }
            if (b.type == "paragraph") {
                const auto s = StripMarkdownInline(b.text);
                if (!s.empty() && s.size() <= 120) {
                    doc.extractedSummary = s;
                    continue;
                }
            }
        }
        if (!doc.extractedTitle.empty() && !doc.extractedSummary.empty()) break;
    }

    return doc;
}

std::string RenderMarkdownToPlainText(const std::string &markdown)
{
    const MarkdownDocument doc = ParseMarkdown(markdown);
    std::ostringstream out;
    bool first = true;

    for (const auto &b : doc.blocks) {
        std::string line;
        if (b.type == "heading") {
            line = StripMarkdownInline(b.text);
        } else if (b.type == "paragraph") {
            line = StripMarkdownInline(b.text);
        } else if (b.type == "quote") {
            line = StripMarkdownInline(b.text);
        } else if (b.type == "bullet_item") {
            line = "- " + StripMarkdownInline(b.text);
        } else if (b.type == "ordered_item") {
            line = "- " + StripMarkdownInline(b.text);
        } else if (b.type == "checklist_item") {
            line = std::string(b.checked ? "[x] " : "[ ] ") + StripMarkdownInline(b.text);
        } else if (b.type == "code_block") {
            line = Trim(b.text);
        } else if (b.type == "divider") {
            line = "";
        }

        if (!first) out << "\n";
        first = false;
        out << line;
    }

    return Trim(out.str());
}

std::string ExportMarkdown(const std::string &title, const std::string &summary, const MarkdownDocument &document)
{
    std::ostringstream out;
    const std::string t = Trim(title);
    if (!t.empty()) {
        out << "# " << t << "\n\n";
    }
    const std::string s = Trim(summary);
    if (!s.empty()) {
        out << "> " << s << "\n\n";
    }

    for (const auto &b : document.blocks) {
        if (b.type == "heading") {
            int lvl = std::max(1, std::min(6, static_cast<int>(b.level)));
            out << std::string(static_cast<size_t>(lvl), '#') << " " << Trim(b.text) << "\n\n";
        } else if (b.type == "paragraph") {
            out << Trim(b.text) << "\n\n";
        } else if (b.type == "quote") {
            out << "> " << Trim(b.text) << "\n\n";
        } else if (b.type == "bullet_item") {
            out << "- " << Trim(b.text) << "\n";
        } else if (b.type == "ordered_item") {
            out << "1. " << Trim(b.text) << "\n";
        } else if (b.type == "checklist_item") {
            out << "- [" << (b.checked ? "x" : " ") << "] " << Trim(b.text) << "\n";
        } else if (b.type == "divider") {
            out << "---\n\n";
        } else if (b.type == "code_block") {
            out << "```";
            if (!Trim(b.language).empty()) out << Trim(b.language);
            out << "\n";
            out << b.text;
            if (!b.text.empty() && b.text.back() != '\n') out << "\n";
            out << "```\n\n";
        }
    }

    return Trim(out.str());
}
