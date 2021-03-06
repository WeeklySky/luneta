module luneta.keyboard;

import std.conv;
import std.range;
import std.algorithm;
import std.array;
import luneta.window;
import luneta.utils;
import luneta.opts;
import fuzzyd.core;
import std.container.binaryheap;
import std.range;

private enum WideKeys
{
    ESC = 27,
    ENTER = 10,
    CTRL_D = 4,
    CTRL_A = 1,
    CTRL_E = 5,
    CTRL_U = 21,
    CTRL_N = 14,
    CTRL_P = 16,
    CTRL_SPACE = 0,
    BACKSPACE = 127
}

/// pressed character type
enum KeyType
{
    FUNCTION_KEY,
    WIDE_CHARACTER,
    UNKOWN
}

enum Terminate
{
    OK,
    EXIT,
    EMPTY
}

/// read a character from the terminal and classify it's type
struct Key
{
    KeyType type; /// key type
    wint_t key; /// key value

    /// read a character from the terminal associated with the current or specified window
    void get()
    {
        switch (get_wch(&key))
        {
        case KEY_CODE_YES:
            type = KeyType.FUNCTION_KEY;
            break;
        case OK:
            type = KeyType.WIDE_CHARACTER;
            break;
        default:
            type = KeyType.UNKOWN;
        }
    }
}

class KeyProcessor
{
private:
    fuzzyFn _fuzzy;
    FuzzyResult[] _all;
    FuzzyResult[] _matches;
    int[] _selectedIdxs;
    int _selected, _cursorx;
    long _total;
    bool _dosearch;
    Terminate _terminate;
    Key _key;

    void buildPattern()
    {
        pattern = pattern.insertAt(cursorx, _key.key);
        cursorx = cursorx + 1;
    }

    void backspace()
    {
        if (pattern.empty)
            return;

        pattern = pattern.deleteAt(cursorx - 1);
        cursorx = cursorx - 1;
    }

    void cursorx(int x) @property
    {
        _cursorx = max(0, x);
    }

    void previousSelection()
    {
        const yLimit = max(0, printArea.height - matches.length.to!int);
        _selected = max(yLimit, _selected - 1);
        _dosearch = false;
    }

    void nextSelection()
    {
        _selected = min(getWindowSize.height - 3, _selected + 1);
        _dosearch = false;
    }

    void specialHandler()
    {
        switch (_key.key)
        {
        case KEY_BACKSPACE:
            backspace;
            break;
        case KEY_DOWN:
            nextSelection;
            break;
        case KEY_UP:
            previousSelection;
            break;
        case KEY_LEFT:
            cursorx = cursorx - 1;
            break;
        case KEY_RIGHT:
            cursorx = min(pattern.walkLength, cursorx + 1);
            break;
        default:
            _dosearch = false;
        }
    }

    void wideHandler()
    {
        switch (_key.key)
        {
        case WideKeys.BACKSPACE:
            backspace;
            break;
        case WideKeys.ESC:
        case WideKeys.CTRL_D:
            _terminate = Terminate.EXIT;
            break;
        case WideKeys.ENTER:
            _terminate = Terminate.OK;
            break;
        case WideKeys.CTRL_A:
            cursorx = 0;
            break;
        case WideKeys.CTRL_E:
            cursorx = pattern.walkLength.to!int;
            break;
        case WideKeys.CTRL_U:
            pattern = "";
            cursorx = 0;
            break;
        case WideKeys.CTRL_N:
            nextSelection;
            break;
        case WideKeys.CTRL_P:
            previousSelection;
            break;
        case WideKeys.CTRL_SPACE:
            appendSelection;
            nextSelection;
            _dosearch = false;
            break;
        default:
            buildPattern;
        }
    }

    void appendSelection()
    {
        const index = getWindowSize.height - _selected - 3;
        if (!_selectedIdxs.canFind(index))
            _selectedIdxs ~= index;
        else
            _selectedIdxs = _selectedIdxs.removeEl(index);
    }

public:
    string pattern;

    this(fuzzyFn fuzzy, ulong dbsize)
    {
        this._key = Key();
        this._dosearch = true;
        this._fuzzy = fuzzy;
        this._terminate = Terminate.EMPTY;
        this.pattern = luneta.opts.query;
        this._all = new FuzzyResult[dbsize];
        this.cursorx = pattern.walkLength.to!int;
        search;
    }

    final bool isIdxSelected(int index)
    {
        return _selectedIdxs.canFind(index);
    }

    final long total() @property
    {
        return _total;
    }

    final FuzzyResult[] all() @property
    {
        return _all;
    }

    final FuzzyResult[] matches() @property
    {
        return _matches;
    }

    final const Terminate terminate() @property
    {
        return _terminate;
    }

    final bool dosearch() @property
    {
        return _dosearch;
    }

    final int selected() @property
    {
        return _selected;
    }

    final Key key() @property
    {
        return _key;
    }

    final int cursorx() @property
    {
        return _cursorx;
    }

    final string[] result() @property
    {
        if (_selectedIdxs.empty)
            appendSelection;

        return _selectedIdxs.map!(x => _matches[x].value).array;
    }

    final void getKey()
    {
        _key.get();
        _dosearch = true;

        if (_key.type is KeyType.WIDE_CHARACTER)
        {
            wideHandler();
        }
        else if (_key.type is KeyType.FUNCTION_KEY)
        {
            specialHandler();
        }
    }

    final void search()
    {
        if (!_dosearch)
            return;

        _total = _fuzzy(pattern, _all);
        const n = min(_total, printArea.height);
        _matches = heapify!"a.score < b.score"(_all).take(n).array;
        _selected = getWindowSize.height - 3;
        _selectedIdxs = [];
    }
}

//----------- tests

@("On wide character - CTRL+A and CTRL+E")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t.pattern = "foobar";

    // cursor at the end of the line
    t._key = Key(KeyType.WIDE_CHARACTER, WideKeys.CTRL_E);
    t.wideHandler;
    assert(t.cursorx == 6);

    // cursor at the beggining of the line
    t._key = Key(KeyType.WIDE_CHARACTER, WideKeys.CTRL_A);
    t.wideHandler;
    assert(t.cursorx == 0);
}

@("On wide character - Terminate with 0 when ENTER")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t._key = Key(KeyType.WIDE_CHARACTER, WideKeys.ENTER);
    t.wideHandler;
    assert(t.terminate == Terminate.OK);
}

@("On wide character - Terminate with 1 when Ctrl+D or Esc ")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t._key = Key(KeyType.WIDE_CHARACTER, WideKeys.CTRL_D);
    t.wideHandler;
    assert(t.terminate == Terminate.EXIT);
}

@("On wide character - Properly build pattern")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t.pattern = "ab";
    t._cursorx = 2;
    t._key = Key(KeyType.WIDE_CHARACTER, 99);
    t.wideHandler;
    assert(t.pattern == "abc");
    assert(t._cursorx == 3);
}

@("On wide character - Insert char at the cursorx position")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t.pattern = "âc";
    t._cursorx = 1;
    t._key = Key(KeyType.WIDE_CHARACTER, 98);
    t.wideHandler;
    assert(t.pattern == "âbc");
    assert(t._cursorx == 2);
}

@("On KEY_RIGHT - Should increment cursorx")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t.pattern = "foo";
    t.cursorx = 2;
    t._key = Key(KeyType.FUNCTION_KEY, KEY_RIGHT);
    t.specialHandler;
    assert(t.cursorx == 3);
}

@("On KEY_RIGHT - Cursorx should not be greater than pattern length")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t.pattern = "fôo";
    t.cursorx = 3;
    t._key = Key(KeyType.FUNCTION_KEY, KEY_RIGHT);
    t.specialHandler;
    assert(t.cursorx == 3);
}

@("On KEY_LEFT - Should decrement cursorx")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t.pattern = "foo";
    t.cursorx = 3;
    t._key = Key(KeyType.FUNCTION_KEY, KEY_LEFT);
    t.specialHandler;
    assert(t.cursorx == 2);
}

@("On KEY_LEFT - Cursorx should not be less than zero")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t.pattern = "foo";
    t.cursorx = 0;
    t._key = Key(KeyType.FUNCTION_KEY, KEY_LEFT);
    t.specialHandler;
    assert(t.cursorx == 0);
}

@("On BACKSPACE - cursor at end of line")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t.pattern = "foo";
    t.cursorx = 3;
    t._key = Key(KeyType.FUNCTION_KEY, KEY_BACKSPACE);
    t.specialHandler;
    assert(t.pattern == "fo");
}

@("On BACKSPACE - cursor at the middle of the pattern")
unittest
{
    auto t = new KeyProcessor(fuzzy([]), 0);
    t.pattern = "bar";
    t.cursorx = 2;
    t._key = Key(KeyType.FUNCTION_KEY, KEY_BACKSPACE);
    t.specialHandler;
    assert(t.pattern == "br");
}
