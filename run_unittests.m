function run_unittests()
    %RUN_UNITTESTS Runs all unit tests
    
    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
    
    try
        % Create a test suite
        suite = ...
            TestSuite.fromPackage('UnitTest', ...
            'IncludingSubpackages', true);

        % Run all tests
        runner = TestRunner.withTextOutput;
        result = runner.run(suite);

        % Display results
        disp(table(result));
        disp(result);

        % Throw an error if any test failed
        if sum([result(:).Failed]) + sum([result(:).Incomplete]) > 0
            error('There are failing unittests!')
        end
    catch err
        disp(err.getReport)
    end
end
