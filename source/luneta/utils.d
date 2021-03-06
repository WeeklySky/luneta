module luneta.utils;

import std.uni;
import std.conv;
import std.range;

/// insert dchar at given index
string insertAt(string str, int index, dchar c)
{
    int i;
    dchar[] result;

    if (index >= str.walkLength)
        return str ~ c.to!string;

    foreach (s; str.byCodePoint)
    {
        if (i is index)
            result ~= c;
        result ~= s;
        i++;
    }

    return result.to!string;
}

/// delete codepoint at index
string deleteAt(string str, int index)
{
    int i;
    dchar[] result;

    foreach (s; str.byCodePoint)
    {
        if (i !is index)
            result ~= s;
        i++;
    }

    return result.to!string;
}

T[] removeEl(T)(T[] lst, T value)
{
    T[] result;
    foreach (v; lst)
    {
        if (v != value)
            result ~= v;
    }
    return result;
}

@("On removeEl")
unittest
{
    auto arr = [10, 20, 70];
    assert(arr.removeEl(20) == [10, 70]);
}

@("On insertAt")
unittest
{
    const s = "ãple";
    const result = s.insertAt(1, 'p');
    const expected = "ãpple";
    assert(expected == result);
}

@("If index is greater than string length insert char at the end of the string")
unittest
{
    const s = "oráng";
    const result = s.insertAt(20, 'e');
    const expected = "oránge";
    assert(expected == result);
}

@("On deleteAt")
unittest
{
    const s = "âppple";
    const result = s.deleteAt(1);
    const expected = "âpple";
    assert(expected == result);
}

@("Do nothing if index is greater than string length")
unittest
{
    const s = "órange";
    const result = s.deleteAt(16);
    const expected = "órange";
    assert(expected == result);
}
