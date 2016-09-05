Matlab Code Analyzer
==================

MATLAB comes with the very important tool MLINT, which can check your code for common defects. Experience shows that these hints can be very helpful for cleaning up MATLAB code, and preventing simple errors. 

Crucially though, MLINT is not a style checker. That is where this program comes in:

Say you have some code in `ugly_code.m`. You can analyze this code for problems using one simple command:

```matlab
check ugly_code.m
```

This might produce a report like this:

```
Code Analysis for ugly_code.m

  Required files: ugly_code.m, ugly_toolbox.m
  Required toolboxes: MATLAB, Signal Processing Toolbox

  Function ugly_code (Line 1, col 18):

    Number of lines: 67 (high)
    Number of function arguments: 2 (good)
    Number of used variables: 5 (good)
    Max level of nesting: 3 (high)
    Code complexity: 6 (good)

    Line 1, col 1: too few comments (2 comments for 67 lines of code)
    Line 1, col 10: return argument 'szOut' is very short (used 5 times across 38 lines)
    Line 1, col 18: function argument 'testInput' is not mentioned in the documentation
    Line 15, col 84: very long line
    Line 20, col 22: no spaces after operator ','
    Line 27, col 1: incorrect indentation
    Line 27, col 1: variable 'szOut' is very short (used 5 times across 38 lines)
    Line 27, col 23: variable 'text' shadows a built-in
    Line 27, col 34: Eval should never be used
    Line 39, col 10: no spaces around operator '='
```

A report like this will be printed for every function in the file, for script-files, and for classes. The more serious of these comments will be highlighted in red, whereas less important ones will stay black. Every line number is clickable and opens directly in the editor.

Additionally, this comes with a settings file `check_settings.m`, which can change the thresholds on all warnings, and even enable or disable whole categories of warnings entirely.
