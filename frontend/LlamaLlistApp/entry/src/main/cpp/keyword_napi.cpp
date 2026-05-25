#include "napi/native_api.h"

#include <string>
#include <vector>
#include <cstdint>

#include "keyword_napi.h"

EXTERN_C_START

static uint32_t fnv1a32(const uint8_t *data, size_t len)
{
    uint32_t hash = 2166136261u;
    for (size_t i = 0; i < len; i++) {
        hash ^= data[i];
        hash *= 16777619u;
    }
    return hash;
}

static std::vector<uint8_t> xorBytes(const std::vector<uint8_t> &input, uint32_t key)
{
    std::vector<uint8_t> out;
    out.resize(input.size());
    uint8_t k0 = static_cast<uint8_t>(key & 0xFF);
    uint8_t k1 = static_cast<uint8_t>((key >> 8) & 0xFF);
    uint8_t k2 = static_cast<uint8_t>((key >> 16) & 0xFF);
    uint8_t k3 = static_cast<uint8_t>((key >> 24) & 0xFF);

    for (size_t i = 0; i < input.size(); i++) {
        uint8_t k = (i % 4 == 0) ? k0 : (i % 4 == 1) ? k1 : (i % 4 == 2) ? k2 : k3;
        out[i] = static_cast<uint8_t>(input[i] ^ k);
    }
    return out;
}

static napi_value EncryptApiKeyNapi(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_value empty;
        napi_create_string_utf8(env, "", 0, &empty);
        return empty;
    }

    auto readStr = [&](napi_value v) -> std::string {
        size_t len = 0;
        napi_get_value_string_utf8(env, v, nullptr, 0, &len);
        std::string s;
        s.resize(len);
        if (len > 0) {
            napi_get_value_string_utf8(env, v, s.data(), len + 1, &len);
        }
        return s;
    };

    const std::string key = readStr(args[0]);
    const std::string salt = readStr(args[1]);

    if (key.empty()) {
        napi_value empty;
        napi_create_string_utf8(env, "", 0, &empty);
        return empty;
    }

    const uint32_t derived = fnv1a32(reinterpret_cast<const uint8_t*>(salt.data()), salt.size()) ^ 0xA5C3F1E7u;

    std::vector<uint8_t> bytes;
    bytes.assign(key.begin(), key.end());

    const std::vector<uint8_t> enc = xorBytes(bytes, derived);

    napi_value arr;
    napi_create_array_with_length(env, enc.size(), &arr);
    for (size_t i = 0; i < enc.size(); i++) {
        napi_value v;
        napi_create_uint32(env, static_cast<uint32_t>(enc[i]), &v);
        napi_set_element(env, arr, i, v);
    }
    return arr;
}

static napi_value DecryptApiKeyNapi(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_value empty;
        napi_create_string_utf8(env, "", 0, &empty);
        return empty;
    }

    bool isArr = false;
    napi_is_array(env, args[0], &isArr);
    if (!isArr) {
        napi_value empty;
        napi_create_string_utf8(env, "", 0, &empty);
        return empty;
    }

    size_t saltLen = 0;
    napi_get_value_string_utf8(env, args[1], nullptr, 0, &saltLen);
    std::string salt;
    salt.resize(saltLen);
    if (saltLen > 0) {
        napi_get_value_string_utf8(env, args[1], salt.data(), saltLen + 1, &saltLen);
    }

    uint32_t derived = fnv1a32(reinterpret_cast<const uint8_t*>(salt.data()), salt.size()) ^ 0xA5C3F1E7u;

    uint32_t len = 0;
    napi_get_array_length(env, args[0], &len);
    std::vector<uint8_t> enc;
    enc.resize(len);

    for (uint32_t i = 0; i < len; i++) {
        napi_value v;
        napi_get_element(env, args[0], i, &v);
        uint32_t b = 0;
        napi_get_value_uint32(env, v, &b);
        enc[i] = static_cast<uint8_t>(b & 0xFF);
    }

    const std::vector<uint8_t> dec = xorBytes(enc, derived);
    std::string out;
    out.resize(dec.size());
    for (size_t i = 0; i < dec.size(); i++) {
        out[i] = static_cast<char>(dec[i]);
    }

    napi_value result;
    napi_create_string_utf8(env, out.c_str(), out.size(), &result);
    return result;
}

static napi_value ExtractKeywordsNapi(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_value arr;
        napi_create_array_with_length(env, 0, &arr);
        return arr;
    }

    // text
    size_t textLen = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &textLen);
    std::string text;
    text.resize(textLen);
    if (textLen > 0) {
        napi_get_value_string_utf8(env, args[0], text.data(), textLen + 1, &textLen);
    }

    int32_t topK = 8;
    if (argc >= 2) {
        napi_get_value_int32(env, args[1], &topK);
        if (topK <= 0) topK = 8;
        if (topK > 50) topK = 50;
    }

    const std::vector<std::string> keywords = ExtractKeywords(text, topK);

    napi_value arr;
    napi_create_array_with_length(env, keywords.size(), &arr);
    for (size_t i = 0; i < keywords.size(); i++) {
        napi_value s;
        napi_create_string_utf8(env, keywords[i].c_str(), keywords[i].size(), &s);
        napi_set_element(env, arr, i, s);
    }
    return arr;
}

static napi_value RenderMarkdownToPlainTextNapi(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_value empty;
        napi_create_string_utf8(env, "", 0, &empty);
        return empty;
    }

    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &len);
    std::string md;
    md.resize(len);
    if (len > 0) {
        napi_get_value_string_utf8(env, args[0], md.data(), len + 1, &len);
    }

    const std::string out = RenderMarkdownToPlainText(md);
    napi_value result;
    napi_create_string_utf8(env, out.c_str(), out.size(), &result);
    return result;
}

static napi_value ParseMarkdownNapi(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    napi_value obj;
    napi_create_object(env, &obj);

    if (argc < 1) {
        napi_value blocks;
        napi_create_array_with_length(env, 0, &blocks);
        napi_set_named_property(env, obj, "blocks", blocks);
        napi_value empty;
        napi_create_string_utf8(env, "", 0, &empty);
        napi_set_named_property(env, obj, "extractedTitle", empty);
        napi_set_named_property(env, obj, "extractedSummary", empty);
        return obj;
    }

    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &len);
    std::string md;
    md.resize(len);
    if (len > 0) {
        napi_get_value_string_utf8(env, args[0], md.data(), len + 1, &len);
    }

    const MarkdownDocument doc = ParseMarkdown(md);

    napi_value blocks;
    napi_create_array_with_length(env, doc.blocks.size(), &blocks);
    for (size_t i = 0; i < doc.blocks.size(); i++) {
        const auto &b = doc.blocks[i];
        napi_value bObj;
        napi_create_object(env, &bObj);

        napi_value type;
        napi_create_string_utf8(env, b.type.c_str(), b.type.size(), &type);
        napi_set_named_property(env, bObj, "type", type);

        if (b.type == "heading") {
            napi_value lvl;
            napi_create_int32(env, b.level, &lvl);
            napi_set_named_property(env, bObj, "level", lvl);
        }
        if (b.type == "checklist_item") {
            napi_value checked;
            napi_get_boolean(env, b.checked, &checked);
            napi_set_named_property(env, bObj, "checked", checked);
        }
        if (b.type == "code_block") {
            napi_value lang;
            napi_create_string_utf8(env, b.language.c_str(), b.language.size(), &lang);
            napi_set_named_property(env, bObj, "language", lang);
        }

        napi_value text;
        napi_create_string_utf8(env, b.text.c_str(), b.text.size(), &text);
        napi_set_named_property(env, bObj, "text", text);

        napi_set_element(env, blocks, i, bObj);
    }

    napi_set_named_property(env, obj, "blocks", blocks);

    napi_value title;
    napi_create_string_utf8(env, doc.extractedTitle.c_str(), doc.extractedTitle.size(), &title);
    napi_set_named_property(env, obj, "extractedTitle", title);

    napi_value summary;
    napi_create_string_utf8(env, doc.extractedSummary.c_str(), doc.extractedSummary.size(), &summary);
    napi_set_named_property(env, obj, "extractedSummary", summary);

    return obj;
}

static napi_value ExportMarkdownNapi(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_value empty;
        napi_create_string_utf8(env, "", 0, &empty);
        return empty;
    }

    auto readStr = [&](napi_value v) -> std::string {
        size_t len = 0;
        napi_get_value_string_utf8(env, v, nullptr, 0, &len);
        std::string s;
        s.resize(len);
        if (len > 0) {
            napi_get_value_string_utf8(env, v, s.data(), len + 1, &len);
        }
        return s;
    };

    const std::string title = readStr(args[0]);
    const std::string summary = readStr(args[1]);
    const std::string markdown = readStr(args[2]);

    const MarkdownDocument doc = ParseMarkdown(markdown);
    const std::string out = ExportMarkdown(title, summary, doc);

    napi_value result;
    napi_create_string_utf8(env, out.c_str(), out.size(), &result);
    return result;
}

static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        {"extractKeywords", nullptr, ExtractKeywordsNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"parseMarkdown", nullptr, ParseMarkdownNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"renderMarkdownToPlainText", nullptr, RenderMarkdownToPlainTextNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"exportMarkdown", nullptr, ExportMarkdownNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"encryptApiKey", nullptr, EncryptApiKeyNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"decryptApiKey", nullptr, DecryptApiKeyNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

EXTERN_C_END

static napi_module keywordModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "keyword_napi",
    .nm_priv = ((void*)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterKeywordModule(void)
{
    napi_module_register(&keywordModule);
}
