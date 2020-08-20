load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "libtwo",
    srcs = ["libtwo.cc", "libtwo_private_header.h"],
    hdrs = ["libtwo_public_header.h"],
    includes = ["."],
    visibility = ["//visibility:public"],
)
