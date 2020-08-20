# buildifier: disable=module-docstring
# load("//bazel:debug.bzl", "describe")
def add_attribute_if_not_present(attrs, attr_name, value):
    attribute = attrs.get(attr_name)
    if attribute:
        return
    attrs[attr_name] = value

# Append item to the list if it is not present in the list yet
def list_append(this_list, new_item):
    for item in this_list:
        if item == new_item:
            return
    this_list.append(new_item)

# Extend the list with only new items from additional list
def list_extend(this_list, additional_list):
    # print("Extend list %s with the list %s" % (this_list, additional_list))
    for item in additional_list:
        list_append(this_list, item)

def list_add(this_list, value):
    if type(value) == "list":
        list_extend(this_list, value)
    else:
        list_append(this_list, value)

# buildifier: disable=function-docstring
def add_to_list_attribute(attrs, attr_name, value):
    # describe(attrs.get(attr_name), 'add_to_list_attribute BEGIN: attrs[%s] for rule %s' % (attr_name, attrs["name"]))

    if not value:
        return
        
    list_attribute = attrs.get(attr_name)
    if list_attribute:
        if not type(list_attribute) == "list":
            fail("_append_to_list_attribute invoked for the attribute (name = %s, value = %s) which is not a list." % (attr_name, list_attribute))
        list_attribute = list(list_attribute) # Clone the list not to mutate existing collection.
    else:
        list_attribute = []
    # The last three lines can be replaced with the following one line:
    # list_attribute = list(list_attribute or [])

    list_add(list_attribute, value)
    attrs[attr_name] = list_attribute
    # describe(attrs.get(attr_name), 'add_to_list_attribute END: attrs[%s] for rule %s' % (attr_name, attrs["name"]))

def location(attrs):
    return "Repository: %s, Package: %s, Rule: %s" % (native.repository_name(), native.package_name(), attrs.get("name"))