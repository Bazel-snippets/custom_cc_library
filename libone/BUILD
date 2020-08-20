# load("@rules_cc//cc:defs.bzl", "cc_library")
load("//bazel:tab_cc_library_internal.bzl", "tab_cc_library_internal")

# cc_library(
tab_cc_library_internal(    
    name = "libone",
    srcs = ["libone.cc", "libone_private_header.h"],
    hdrs = ["libone_public_header.h"],
    includes = ["."],
    visibility = ["//visibility:public"],
)
