#ifndef KEYWORD_NAPI_H
#define KEYWORD_NAPI_H

#include <string>
#include <vector>

struct MarkdownInlineNode {
    std::string type;
    std::string text;
    std::string href;
};

struct MarkdownBlockNode {
    std::string type;
    int32_t level = 0;
    bool checked = false;
    std::string text;
    std::vector<MarkdownInlineNode> inlines;
    std::vector<std::string> items;
    std::vector<bool> checkedItems;
    std::string language;
};

struct MarkdownDocument {
    std::vector<MarkdownBlockNode> blocks;
    std::string extractedTitle;
    std::string extractedSummary;
};

std::vector<std::string> ExtractKeywords(const std::string &text, int32_t topK);
MarkdownDocument ParseMarkdown(const std::string &markdown);
std::string RenderMarkdownToPlainText(const std::string &markdown);
std::string ExportMarkdown(const std::string &title, const std::string &summary, const MarkdownDocument &document);

#endif