"""
    This file was created by Konstantin Erman (konste _at_ ermank _dot_ com) in Spring 2020 for the purpose of debugging complex Bazel build custom rules.
"""

# load("@tab_toolchains//bazel/providers:providers.bzl", "SingleBinaryInfo", "ListBinaryInfo", "DependenciesInfo", "ListDependenciesInfo", 'SharedLibrariesInfo')

types_to_show_in_one_line = ['string', 'int', 'bool', 'File', 'Target', 'Label']
# obj_repr_empty_keep_scanning = [
#     'runfiles', 'FilesToRunProvider', 'OutputGroupInfo', 'CcInfo', 'CompilationContext', 'LinkingContext', 'LinkerInput'
# ]
structs_not_to_parse = ['rule']
how_many_list_items_to_show = 5
attribute_names_to_skip = [
    'tree_relative_path', # To avoid error "tree_relative_path not allowed for files that are not tree artifact files."
    'rule', # To avoid error "'rule' is only available in aspect implementations."
    'build_setting_value', # To avoid error "attempting to access 'build_setting_value' of non-build setting."
    'aspect_ids', # To avoid error "'aspect_ids' is only available in aspect implementations."
    'actions', # To avoid reporting useless actions property of Target.
]

# buildifier: disable=function-docstring
def query_provider(provider, stack, obj, name):
    if provider in obj:

        provider_name = str(provider)
        if provider_name.startswith('<function '):
            provider_name = provider_name[len('<function '):]
        if provider_name.endswith('>'):
            provider_name = provider_name[:-len('>'):]
        # print('provider_name = %s' % provider_name)

        stack.append(struct(obj = obj[provider], name = (name or "") + '[' + provider_name + ']', prefix = ''))

def query_known_providers(stack, obj, name):
    # Full list of documented providers is here: https://docs.bazel.build/versions/master/skylark/lib/skylark-provider.html
    known_providers = [
        # ListBinaryInfo, # Commented out to make this file self-contained.
        # ListDependenciesInfo, # Not interested in it at this time
        
        CcInfo,

        # PlatformInfo, # https://docs.bazel.build/versions/master/skylark/lib/PlatformInfo.html

        PyInfo,
        PyRuntimeInfo,

        # CcStarlarkApiProvider, # unknown
        CcToolchainConfigInfo,
        cc_common.CcToolchainInfo,
        # CompilationContext, # unknown

        # ConstraintCollection, # unknown
        # ConstraintSettingInfo, # unknown
        # ConstraintValueInfo, # unknown

        # InstrumentedFilesInfo, # unknown
        # TemplateVariableInfo, # unknown
        # ToolchainInfo, # unknown
        # ToolchainTypeInfo, # unknown
    ]

    for provider in known_providers:
        query_provider(provider, stack, obj, name)

def trace(msg):
    yellow = "\033[1;33m"
    no_color = "\033[0m"

    # buildifier: disable=print
    print("%sTrace:%s %s" % (yellow, no_color, msg))

# buildifier: disable=function-docstring
def describe_object(obj, name = None, prefix = ''):
    # if not obj:
    #     return ('', False)
    
    if name == 'licenses':
        return ('', False)

    object_type = type(obj)
    # print("object_type = %s" % object_type) 

    if object_type == 'function':
        return ('', False)

    keep_scanning = True
    obj_repr = '' # <empty>

    if object_type in types_to_show_in_one_line:
        obj_repr = str(obj)
        keep_scanning = False
    
    elif object_type == 'list':
        obj_repr = 'list of %s elements' % len(obj)

    elif object_type == 'depset':
        obj_repr = 'depset of %s elements' % len(obj.to_list())

    elif object_type == 'dict':
        obj_repr = 'dict of %s elements' % len(obj.items())

    elif object_type == 'struct' and name in structs_not_to_parse:
        obj_repr = obj.location
        keep_scanning = False

    # elif object_type in obj_repr_empty_keep_scanning:
    #     pass # obj_repr empty, keep scanning.

    else:
        max_str_len = 70
        obj_repr = str(obj)[0:max_str_len]
        if len(obj_repr) == max_str_len:
            obj_repr += "..."

    # print('\nobject_type = %s, obj_repr = %s' % (object_type, obj_repr))

    if name:
        named_prefix = '\n%s%s(%s): ' % (prefix, name, object_type)
    else:
        named_prefix = '\n%s(%s): ' % (prefix, object_type)

    new_text = named_prefix + obj_repr
    return (new_text, keep_scanning)


def describe_to_string(obj, name = None):
    """Print the properties of the given struct obj.

    Args:
        obj: the object to introspect
        name: the name of the object to introspect
    """

    msg = ''
    state = struct(obj = obj, name = name, prefix = '')
    stack = [state] # list has methods append and pop
    for _ in range (2147483647):
        state = stack.pop()
        (new_text, keep_scanning) = describe_object(state.obj, state.name, state.prefix)
        msg += new_text

        depth = len(stack)
        #print('depth = %s' % depth)
        if depth == 0 and type(obj) == 'Target':
            keep_scanning = True # If Target is what we are trying to describe, then force expanding it even when describe_object sets keep_scanning to False.

        if keep_scanning:
            # print('\nscanning "%s" of type %s' % (state.name, type(state.obj)))
            obj = state.obj
            if type(obj) == 'depset':
                obj = obj.to_list()
            if type(obj) == 'list' and len(obj) > 0:
                index = min(how_many_list_items_to_show - 1, len(obj) - 1)
                for item in reversed(obj):
                    attribute_name = 'item[%s]' % index
                    new_state = struct(obj = item, name = attribute_name, prefix = state.prefix + '    ')
                    stack.append(new_state)
                    index = index - 1
                    if index < 0:
                        break
            if type(obj) == 'dict' and len(obj.items()) > 0:
                for key, value in reversed(obj.items()):
                    new_state = struct(obj = value, name = key, prefix = state.prefix + '    ')
                    stack.append(new_state)
            else:
                if type(obj) == 'Target':
                    query_known_providers(stack, obj, name)

                for attribute_name in reversed(dir(obj)):
                    # print('attribute_name = %s' % attribute_name)
                    if attribute_name in attribute_names_to_skip:
                        continue
                    attribute_value = getattr(obj, attribute_name)
                    # if attribute_value and type(attribute_value) != 'function':
                    #     print('\n    found attribute "%s" of type %s and value %s' % (attribute_name, type(attribute_value), attribute_value))
                    new_state = struct(obj = attribute_value, name = attribute_name, prefix = state.prefix + '    ')
                    stack.append(new_state)

        if len(stack) == 0:
            break
    return msg

def describe(obj, name = None):
    """Print the properties of the given struct obj.

    Args:
        obj: the struct to introspect
        name: the name of the struct we are introspecting.
    """
    msg = describe_to_string(obj, name)
    trace(msg)

# buildifier: disable=function-docstring
def _dump_impl(ctx):
    target = ctx.attr.src
    name = ctx.label.name
    msg = describe_to_string(target, name)
    trace(msg)

    return [
        DefaultInfo(),
        CcInfo(),  # This is so that cc_ rules can depend on it.
    ]

dump = rule(
    implementation = _dump_impl,
    attrs = {
        "src": attr.label(),  # allow_single_file=True
    },
)
