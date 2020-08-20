workspace(name = "private_headers_tryout") 

# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
 
git_repository(
    name = "bazel_skylib",
    remote = "git@gitlab.tableausoftware.com:tableaubuild/bazel/mirrors/bazel/bazel-skylib.git",
    commit = "e59b620b392a8ebbcf25879fc3fde52b4dc77535",
    shallow_since = "1570639401 -0400", 
)

git_repository(
    name = "rules_cc",
    remote = "https://github.com/bazelbuild/rules_cc.git",
    commit = "810a11e77285e97e5a69e6f1be3c8d647286407f",
    shallow_since = "1581692351 -0800", 
) 