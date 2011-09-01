#!/usr/bin/env python
# -*- coding: utf8 -*-
import re
import sys
import getopt

from lxml import etree, html


def get_index(tree, elem):
    index = tree.getpath(elem).split('/')[-1]
    if '[' in index:
        index = re.findall('\d+', index)[0]
        return index
    return None


def get_path(elem, doc):
    nodes = []
    parent = elem
    tree = etree.ElementTree(doc)
    while parent is not None:
        attrs = []
        index = get_index(tree, parent)
        for key, value, in parent.attrib.items():
            if key in ['class', 'id', 'color', 'font']:
                attrs.append("@%s=\"%s\"" % (key, value))
            if index:
                attrs.append('position()=%s' % index)
        if attrs:
            nodes.append("%s[%s]" % (parent.tag, " and ".join(attrs)))
        else:
            nodes.append("%s" % parent.tag)
        parent = parent.getparent()
    return list(reversed(nodes))


def main(search_string, with_percentage=False, with_content=False):
    content = ""

    for line in sys.stdin:
        content += line

    for string in search_string:
        do_search(string, content)


def do_search(search_string, content):
    doc = html.fromstring(content)
    text_elements = doc.xpath('//text()')
    search_string_length = len(search_string)

    # store the found paths here
    paths = []

    for text_elem in text_elements:
        text_string = unicode(text_elem.encode('utf-8'), errors='ignore')
        text_string = text_string.lower().strip()

        for char in ('\n', '\t', '\r'):
            text_string = text_string.replace(char, '')

        if search_string in text_string:
            path = get_path(text_elem.getparent(), doc)
            result = ''
            for idx, _ in enumerate(path):
                temp = "//" + "/".join(path[(-1) * (idx + 1):])
                if len(doc.xpath(temp)) == 1:
                    result = temp
                    break
            text_elem_length = len(text_string)
            percentage = 100 * (
                float(search_string_length) / float(text_elem_length))
            paths.append((percentage, "'%s/text()'" % result, text_string))

    paths = sorted(paths, reverse=True)
    for (percentage, path, content) in paths:
        if with_percentage and with_content:
            print '%5.2f | %s | %s' % (percentage, path, content)
        elif with_percentage:
            print '%5.2f | %s' % (percentage, path)
        elif with_content:
            print '%s | %s' % (path, content)
        else:
            print '%s' % path


if __name__ == '__main__':
    with_percentage = False
    with_content = False

    try:
        opts, args = getopt.getopt(sys.argv[1:], "pc", [
            "percentage",
            "content"
        ])
    except getopt.GetoptError, err:
        print(str(err))
        sys.exit(1)

    for o, a in opts:
        if o in ("-p", "--percentage"):
            with_percentage = True
        elif o in ("-c", "--content"):
            with_content = True
        else:
            print("Unknown option (%s)" % o)
            sys.exit(1)

    if not args:
        print("Need at least one string to search for.")
        sys.exit(1)

    main(args, with_percentage, with_content)
