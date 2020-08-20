# buildifier: disable=module-docstring
# load("@tab_toolchains//bazel/rules:debug.bzl", "describe")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("//bazel:attribute_manipulations.bzl", "location")

# buildifier: disable=function-docstring
def resolve_library(library, pic_enabled, link_deps_statically):
    if pic_enabled:
        resolved_pic_static_library = library.pic_static_library
        resolved_static_library = None
    else:
        resolved_pic_static_library = None
        resolved_static_library = library.static_library

    if library.resolved_symlink_interface_library:
        resolved_interface_library = library.resolved_symlink_interface_library
    else:
        resolved_interface_library = library.interface_library

    if library.resolved_symlink_dynamic_library:
        # print('\nlibrary.resolved_symlink_dynamic_library.basename = %s' % library.resolved_symlink_dynamic_library.basename)
        # print('\nlibrary.resolved_symlink_dynamic_library.dirname = %s' % library.resolved_symlink_dynamic_library.dirname)
        resolved_dynamic_library = library.resolved_symlink_dynamic_library
    else:
        # print('\nlibrary.dynamic_library.basename = %s' % library.dynamic_library.basename)
        # print('\nlibrary.dynamic_library.dirname = %s' % library.dynamic_library.dirname)
        resolved_dynamic_library = library.dynamic_library

    if (resolved_static_library or resolved_pic_static_library) and resolved_dynamic_library:
        if link_deps_statically:
            resolved_dynamic_library = None
            resolved_interface_library = None
        else:
            resolved_pic_static_library = None
            resolved_static_library = None

    file_to_link = "Unknown"
    file_to_link_type = "Unknown"
    if resolved_pic_static_library:
        file_to_link = resolved_pic_static_library
        file_to_link_type = "Static"

    if resolved_static_library:
        file_to_link = resolved_static_library
        file_to_link_type = "Static"

    elif resolved_interface_library:
        file_to_link = resolved_interface_library
        file_to_link_type = "Interface"

    elif resolved_dynamic_library:
        file_to_link = resolved_dynamic_library
        file_to_link_type = "Dynamic"

    return file_to_link, file_to_link_type

def deduplicate_linker_inputs(linking_contexts):
    """
    Takes the list of linking_contexts and deduplicate linker_inputs by owner.
    """

    linker_inputs = {}  # We need to deduplicate linker_inputs by the owner.
    for linking_context in linking_contexts:
        # describe(linking_context, 'linking_context (%s)' % ctx.label)
        for linker_input in linking_context.linker_inputs.to_list():
            if linker_inputs.get(linker_input.owner):
                continue

            # if len(linker_input.libraries) > 0 or len(linker_input.additional_inputs) > 0: # or len(linker_input.user_link_flags) > 0
            linker_inputs[linker_input.owner] = linker_input

    # print('linker_inputs = %s' % linker_inputs)
    return linker_inputs.values()

# buildifier: disable=function-docstring
def _library_not_empty(library):
    if library.dynamic_library: return True
    if library.resolved_symlink_dynamic_library: return True
    if library.interface_library: return True
    if library.resolved_symlink_interface_library: return True
    if library.static_library: return True
    if library.pic_static_library: return True
    if library.objects and len(library.objects) > 0: return True
    if library.pic_objects and len(library.pic_objects) > 0: return True
    if library.lto_bitcode_files and len(library.lto_bitcode_files) > 0: return True
    if library.pic_lto_bitcode_files and len(library.pic_lto_bitcode_files) > 0: return True
    return False

# buildifier: disable=function-docstring
def _linker_input_not_empty(linker_input):
    for library in linker_input.libraries:
        if _library_not_empty(library): return True
    if linker_input.user_link_flags and len(linker_input.user_link_flags) > 0: return True
    if linker_input.additional_inputs and len(linker_input.additional_inputs) > 0: return True
    return False

# buildifier: disable=function-docstring
def filter_empty_linker_inputs(linker_inputs):
    filtered_linker_inputs = []
    for linker_input in linker_inputs:
        if _linker_input_not_empty(linker_input):
            filtered_linker_inputs.append(linker_input)
    return filtered_linker_inputs

# buildifier: disable=function-docstring
def filter_static_libs_from_linker_inputs(linker_inputs, pic_enabled, link_deps_statically):
    filtered_linker_inputs = []
    for linker_input in linker_inputs:
        dynamic_or_interface_libraries_in_linker_input = []
        for library in linker_input.libraries:
            file_to_link, file_to_link_type = resolve_library(library, pic_enabled, link_deps_statically)
            if file_to_link_type in ["Dynamic", "Interface"]:
                dynamic_or_interface_libraries_in_linker_input.append(library)
        if len(linker_input.libraries) == len(dynamic_or_interface_libraries_in_linker_input):
            # All libs in this linker_input are dynamic or interface, we can take it as is.
            filtered_linker_inputs.append(linker_input)
        elif len(dynamic_or_interface_libraries_in_linker_input) == 0:
            # All libs in linker_input are static - we can skip it.
            pass
        else:
            new_linker_input = cc_common.create_linker_input(
                owner = linker_input.owner,
                libraries = depset(dynamic_or_interface_libraries_in_linker_input),
                user_link_flags = depset(linker_input.user_link_flags),
                additional_inputs = depset(linker_input.additional_inputs),
            )
            filtered_linker_inputs.append(new_linker_input)
    return filtered_linker_inputs

# buildifier: disable=function-docstring
def filter_attributes(**attrs):
    # Do not generate shared library binary when the list of sources is empty. Delegate to the standard cc_library instead.
    # This is done to prevent generating binaries for the Boost header only libraries.
    srcs = attrs.get("srcs")
    if not srcs or (type(srcs) == "list" and len(srcs) == 0):
        # print('\n%s is a header only library' % name)
        filtered_attrs = {}
        for key, value in attrs.items():
            if key in ["public_deps", "binary_name"]:  # Exclude attibutes cc_library does not understand.
                continue
            filtered_attrs[key] = value

        # Ignore "deps" attribute and use "public_deps" instead if it is specified.
        if attrs.get("deps") and len(attrs.get("deps")) > 0:
            fail('deps attribute does not make sense for the header only library. Do you mean public_deps?" %s' % location(attrs))
        filtered_attrs["deps"] = attrs.get("public_deps")

        # We may also try to use tab_cc_funnel_internal here, but the standard cc_library seems safer and more versatile.
        cc_library(**filtered_attrs)
        return []
    else:
        # print ('tags = %s' % tags)
        filtered_attrs = {}
        for key, value in attrs.items():
            # Append "vsproject" to tags if it is not already there.
            if key == "tags":
                updated_tags = []
                updated_tags.extend(value)  # Copying immutable list to mutable
                if not "vsproject" in updated_tags:
                    updated_tags.append("vsproject")

                # print ('updated_tags = %s' % updated_tags)
                filtered_attrs[key] = updated_tags
            else:
                filtered_attrs[key] = value

        filtered_attrs["platform"] = select({
            "//bazel:windows": "windows",
            "//bazel:linux": "linux",
            "//bazel:osx": "osx",
            "//conditions:default": "other",
        })
        return filtered_attrs

# buildifier: disable=function-docstring
def library_to_linking_context(library_to_link, owner):
    linker_input = cc_common.create_linker_input(
        owner = owner,
        libraries = depset([library_to_link]),
    )

    linking_context = cc_common.create_linking_context(linker_inputs = depset([linker_input]))
    return linking_context

# buildifier: disable=function-docstring
def static_lib_to_linking_context(static_lib, ctx, pic_enabled, feature_configuration, cc_toolchain):
    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        pic_static_library = static_lib,
        static_library = static_lib,
    )
    return library_to_linking_context(library_to_link, ctx.label)
