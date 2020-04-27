module luneta.keyboard;

import std.conv;
import std.range;
import std.algorithm;
import std.array;
import luneta.window;
import luneta.utils;
import fuzzyd.core;

private enum WideKeys
{
    ESC = 27,
    ENTER = 10,
    CTRL_D = 4,
    CTRL_A = 1,
    CTRL_E = 5,
    CTRL_U = 21,
    CTRL_N = 14,
    CTRL_P = 16
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
    int _selected, _cursorx;
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
        const yLimit = max(0, getWindowSize.height - matches.length.to!int - 2);
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
        default:
            buildPattern;
        }
    }

public:
    string pattern;

    this(fuzzyFn fuzzy)
    {
        this._key = Key();
        this._dosearch = true;
        this._fuzzy = fuzzy;
        this._terminate = Terminate.EMPTY;
        this.pattern = "";
        search;
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

    final FuzzyResult[] all() @property
    {
        return _all;
    }

    final int cursorx() @property
    {
        return _cursorx;
    }

    final string getSelected()
    {
        immutable index = getWindowSize.height - _selected - 3;
        return matches[index].value;
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

        _all = _fuzzy(pattern);
        _matches = pattern.empty ? _all : _all.filter!(m => m.score > 0).array();
        _selected = getWindowSize.height - 3;
    }
}
