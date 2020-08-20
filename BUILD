load("@rules_cc//cc:defs.bzl", "cc_binary")
load("//bazel:debug.bzl", "dump")

dump(
    name = "dump_libone",
    src = "//libone",
)

dump(
    name = "dump_libtwo",
    src = "//libtwo",
)

cc_binary(
    name = "main",
    srcs = ["main.cc"],
    deps = [
        "//libone",
        "//libtwo",
    ],
)
