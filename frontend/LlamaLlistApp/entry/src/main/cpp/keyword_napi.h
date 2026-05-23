#ifndef KEYWORD_NAPI_H
#define KEYWORD_NAPI_H

#include <string>
#include <vector>

std::vector<std::string> ExtractKeywords(const std::string &text, int32_t topK);

#endif