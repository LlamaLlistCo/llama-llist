#include "napi/native_api.h"

EXTERN_C_START

static napi_value ExtractKeywordsNapi(napi_env env, napi_callback_info info)
{
    napi_value arr;
    napi_create_array_with_length(env, 0, &arr);
    return arr;
}

static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        {"extractKeywords", nullptr, ExtractKeywordsNapi, nullptr, nullptr, nullptr, napi_default, nullptr}
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
