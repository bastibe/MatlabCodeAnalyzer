function test_MatlabIndentedClass()

assert(check_settings('indentation_check_like_matlab') == true)

addpath('testFiles')
check('testFiles/MatlabIndentedClass.m');

end