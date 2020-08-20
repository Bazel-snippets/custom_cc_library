# Modelled after https://github.com/bazelbuild/bazel/blob/master/src/test/shell/bazel/cc_api_rules.bzl
# Another (older) variant is here: https://github.com/bazelbuild/rules_cc/blob/master/examples/my_c_archive/my_c_compile.bzl

# buildifier: disable=module-docstring
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("@bazel_skylib//lib:paths.bzl", "paths") 
load("//bazel:tab_cc_helpers_internal.bzl", "static_lib_to_linking_context", "filter_attributes")
# load("@tab_toolchains//bazel/rules:debug.bzl", "describe")
load("//bazel:attribute_manipulations.bzl", "location", "add_to_list_attribute")

def _tab_cc_library_internal_rule_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    pic_enabled = cc_common.is_enabled(feature_configuration = feature_configuration, feature_name = 'pic')

    compilation_contexts = []
    linking_contexts = []
    for dep in ctx.attr.public_deps:
        if CcInfo in dep:
            compilation_contexts.append(dep[CcInfo].compilation_context)
            linking_contexts.append(dep[CcInfo].linking_context)
            # describe(dep[CcInfo].linking_context, 'dep[CcInfo].linking_context ' + ctx.label.name)
    for dep in ctx.attr.deps:
        if CcInfo in dep:
            compilation_contexts.append(dep[CcInfo].compilation_context)
            # Don't append linking contexts from non-public deps.
            # We don't want static library to link with the dependencies it is not supposed to carry.

    # Converting cc_binary API to cc_common API.
    filtered_srcs = []
    private_hdrs = []
    input_objects = []
    input_pic_objects = []
    for file in ctx.files.srcs:
        # print('file.extension = %s' % file.extension)
        if file.extension in ["cc", "cpp", "cxx", "c++", "C", "cu", "cl", "c", "s", "asm"]:
            filtered_srcs.append(file)
        elif file.extension in ["lib", "a"]:
            linking_contexts.append(static_lib_to_linking_context(file, ctx, pic_enabled, feature_configuration, cc_toolchain))
        elif file.extension in ["obj", "o"]:
            if file.basename.endswith(".pic.o"):
                input_pic_objects.append(file)
            else:
                input_objects.append(file)
        else:
            private_hdrs.append(file)

    hdrs = []
    for file in ctx.files.hdrs:
        # We don't let headers with no extension reach to cc_common.compile and confuse it
        # But at the same time they are discoverable for collect_deps.
        if not file.extension == '':
            hdrs.append(file)

    # To mimic cc_library behavior we need to translate "includes" attribute to "system_includes".
    system_includes_list = []
    for include_folder in ctx.attr.includes:
        system_include = paths.normalize(paths.join(ctx.label.workspace_root, ctx.label.package, include_folder))
        system_includes_list.append(system_include)
        system_include_from_execroot = paths.join(ctx.bin_dir.path, system_include)
        system_includes_list.append(system_include_from_execroot)
    # describe(system_includes_list, 'system_includes_list')

    # Create compilation context for the newly created binary.
    # Combine it with the compilation contexts of public dependencies to propagate upstream.
    new_compilation_context = cc_common.create_compilation_context(
        headers = depset(ctx.files.hdrs),
        system_includes = depset(system_includes_list),
        includes = depset(ctx.attr.includes), # For completeness.
        # quote_includes = ???,
        defines = depset(ctx.attr.defines),
        local_defines = depset(ctx.attr.local_defines), # For completeness.
    )
    # describe(new_compilation_context, 'new_compilation_context (%s)' % ctx.label)

    (compiled_compilation_context, compilation_outputs) = cc_common.compile(
        name = ctx.label.name,
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        public_hdrs = hdrs,
        private_hdrs = private_hdrs,
        srcs = filtered_srcs,
        includes = ctx.attr.includes,
        # quote_includes = ???,
        system_includes = system_includes_list,
        defines = ctx.attr.defines,
        local_defines = ctx.attr.local_defines,
        user_compile_flags = ctx.attr.copts,
        compilation_contexts = compilation_contexts,
        # additional_inputs = ? Do we need it?
	# The following two attributes supposed to be enabled in some Bazel version AFTER 3.5.0
        # include_prefix = ctx.attr.include_prefix,
        # strip_include_prefix = ctx.attr.strip_include_prefix,
    )
    # describe(compiled_compilation_context, 'compiled_compilation_context (%s)' % ctx.label)
    # describe(compilation_outputs, 'compilation_outputs (%s)' % ctx.label)
    # print("pic_enabled = %s" % pic_enabled)
    # print(feature_configuration)

    # Append input object files to those produced by compilation.
    objects = []
    objects.extend(compilation_outputs.objects)
    objects.extend(input_objects)
    pic_objects = []
    pic_objects.extend(compilation_outputs.pic_objects)
    pic_objects.extend(input_objects)

    amended_compilation_outputs = cc_common.create_compilation_outputs(objects = depset(objects), pic_objects = depset(pic_objects))
    # describe(amended_compilation_outputs, 'amended_compilation_outputs (%s)' % ctx.label)

    (new_linking_context, linking_outputs) = cc_common.create_linking_context_from_compilation_outputs(
        name = ctx.label.name,
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_link_flags = ctx.attr.linkopts,
        compilation_outputs = amended_compilation_outputs,
        # additional_inputs = input_objects,
        linking_contexts = linking_contexts,
        alwayslink = ctx.attr.alwayslink,
        disallow_dynamic_library = ctx.attr.linkstatic,
    )
    # describe(linking_outputs)

    ccinfo_list = []
    # Collect CcInfo from public dependencies
    for dep in ctx.attr.public_deps:
        if CcInfo in dep:
            ccinfo_list.append(dep[CcInfo])
            # describe(dep[CcInfo], 'dep[CcInfo] (%s)' % dep.label)

    # Add newly generated cc_info to the list of public deps.
    new_ccinfo = CcInfo(compilation_context = new_compilation_context, linking_context = new_linking_context)

    # Create final merged CcInfo to return
    merged_ccinfo = cc_common.merge_cc_infos(direct_cc_infos = [new_ccinfo], cc_infos = ccinfo_list)
    # describe(merged_ccinfo, output_name)
    
    objects = []
    if pic_enabled:
        objects.extend(compilation_outputs.pic_objects)
    else:
        objects.extend(compilation_outputs.objects)

    archive = []
    library = linking_outputs.library_to_link
    # describe(library)
    if library:
        if library.pic_static_library:
            archive.append(library.pic_static_library)
        if library.static_library:
            archive.append(library.static_library)
    
    output_group_info = OutputGroupInfo(
        archive = depset(archive),
        compilation_outputs = depset(objects),
    )

    return [
        DefaultInfo(
            files = depset(archive),
        ),
        merged_ccinfo,
        output_group_info,
    ]

tab_cc_library_internal_rule = rule(
    implementation = _tab_cc_library_internal_rule_impl,
    attrs = {
        "hdrs": attr.label_list(allow_files = True),
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(
            allow_empty = True,
            providers = [[CcInfo]],
        ),
        "public_deps": attr.label_list(
            allow_empty = True,
            providers = [CcInfo],
        ),
        "copts": attr.string_list(),
        "linkopts": attr.string_list(),
        "linkstatic": attr.bool(default = True),
        "includes": attr.string_list(),
        "defines": attr.string_list(),
        "local_defines": attr.string_list(),
        "alwayslink": attr.bool(default = False),
        "platform": attr.string(mandatory = True),
        "data": attr.label_list(
            default = [],
            allow_files = True,
        ),
        "include_prefix": attr.string(),
        "strip_include_prefix": attr.string(),
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
    },
    fragments = ["cpp"],
    toolchains = ["@rules_cc//cc:toolchain_type"],
)

# buildifier: disable=function-docstring
def tab_cc_library_internal(**attrs):
    # Enforce that tab_cc_library only builds static version of the library.
    if attrs.get("linkstatic") == False:
        fail('tab_cc_library only intended to build static libraries and "linkstatic = False" is not allowed. %s' % location(attrs))
    attrs["linkstatic"] = True

    feature_flag = "!use_native_cc_library"
    if feature_flag == "use_native_cc_library":
        # For native cc_library public and regular deps are the same.
        public_deps = attrs.pop("public_deps", None)
        add_to_list_attribute(attrs, "deps", public_deps)

        cc_library(**attrs)
        return

    filtered_attrs = filter_attributes(**attrs)
    if len(filtered_attrs) == 0:
        return

    # print('\n%s is a shared library' % name)
    tab_cc_library_internal_rule(**filtered_attrs)
