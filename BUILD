objc_library(
    name = "fmdb",
    srcs = glob(["src/fmdb/*.m"], exclude=["src/fmdb.m"]),
    hdrs = glob(["src/fmdb/*.h"]),
    includes = ["src"],
    sdk_dylibs = ["sqlite3"],
    visibility = ["//visibility:public"],
)

objc_library(
    name = "fmdb_fts",
    srcs = glob(["src/extra/fts3/*.m"]),
    hdrs = glob(["src/extra/fts3/*.h"]),
    deps = [":fmdb"],
    visibility = ["//visibility:public"],
)

objc_library(
    name = "fmdb_tests_lib",
    srcs = glob(["Tests/*.h", "Tests/*.m"]),
    deps = [":fmdb_fts"],
    includes = ["src/fmdb", "src/extra/fts3"],
    pch = "Tests/Tests-Prefix.pch",
)

load("@build_bazel_rules_apple//apple:macos.bzl", "macos_unit_test")
macos_unit_test(
    name = "fmdb_tests",
    minimum_os_version = "10.11",
    deps = [":fmdb_tests_lib"],
)
