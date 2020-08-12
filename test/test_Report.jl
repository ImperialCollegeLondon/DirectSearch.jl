@testset "Reporting" begin

    p = DSProblem(3, objective = x -> sum(x.^2), initial_point= [10, 10, 10])
    Optimize!(p)

    @testset "report_config" begin
        rc = DS.report_config(p)

        @test rc.title == "Config"

        names = [e.first for e in rc.entries if e != nothing]

        @test "Search" in names
        @test "Poll" in names
        @test "Mesh" in names
        @test "Mesh Scale" in names
        @test "Opportunistic" in names
        @test "Number of processes" in names
        @test "Max simultanious evaluations" in names

        #just check that it doesn't crash
        @test typeof(DS.format(rc)) == String
    end

    @testset "report_config" begin
        rc = DS.report_status(p)

        @test rc.title == "Status"

        names = [e.first for e in rc.entries if e != nothing]

        @test "Function Evaluations" in names
        @test "Iterations" in names
        @test "Optimization Status" in names
        @test "Runtime" in names
        @test "Search Time" in names
        @test "Poll Time" in names
        @test "Blackbox Evaluation Time" in names

        @test typeof(DS.format(rc)) == String
    end

    @testset "report_problem" begin
        rc = DS.report_problem(p)

        @test rc.title == "Optimization Problem"

        names = [e.first for e in rc.entries if e != nothing]

        @test "Variables" in names
        @test "Initial Point" in names
        @test "Sense" in names
        @test "Feasible Solution" in names
        @test "Feasible Cost" in names
        @test "Infeasible Solution" in names
        @test "Infeasible Cost" in names

        @test typeof(DS.format(rc)) == String
    end
end
