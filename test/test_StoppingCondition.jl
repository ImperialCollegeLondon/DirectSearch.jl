@testset "StoppingCondition" begin 

    @testset "Defaults" begin
        p = DSProblem(4)
        @test typeof(p.stoppingconditions[1]) == DS.IterationStoppingCondition
        @test typeof(p.stoppingconditions[2]) == DS.MeshPrecisionStoppingCondition
        @test p.stoppingconditions[1].limit == 1000

        p = DSProblem(4; iteration_limit=100)
        @test p.stoppingconditions[1].limit == 100
    end

    @testset "AddStoppingCondition" begin
        p = DSProblem(4)
        
        test_stopping_cond = DS.IterationStoppingCondition(1234)
        DS.AddStoppingCondition(p, test_stopping_cond)
        @test p.stoppingconditions[3].limit == 1234
    end

    @testset "CheckStoppingConditions" begin
        p = DSProblem(4)
        c = DS.AbstractStoppingCondition[]
        @test DS.CheckStoppingConditions(p, c) == true

        p.status.iteration = 100
        push!(c, DS.IterationStoppingCondition(200))
        @test DS.CheckStoppingConditions(p, c) == true

        p.status.iteration = 200
        @test DS.CheckStoppingConditions(p, c) == false

        p.status.iteration = 300
        @test DS.CheckStoppingConditions(p, c) == false


        push!(c, DS.IterationStoppingCondition(400))
        @test DS.CheckStoppingConditions(p, c) == false
    end

    @testset "SetStatus" begin
        p = DSProblem(4)

        @test p.status.optimization_status == "Unoptimized"
 
        struct test_sc <: DS.AbstractStoppingCondition end
        DS.StoppingConditionStatus(::test_sc) = "test status message"
        DS.CheckStoppingCondition(p::DSProblem, s::test_sc) = false

        DS.SetStatus(p, test_sc())
        @test p.status.optimization_status == "test status message"

        #First false sc reached in the array is the reported status 
        DS.AddStoppingCondition(p, test_sc())
        @test DS.CheckStoppingConditions(p) == false
        @test p.status.optimization_status == "test status message"
        p.status.iteration = 1001
        @test DS.CheckStoppingConditions(p) == false
        @test p.status.optimization_status == "Iteration limit"
    end

    @testset "StoppingConditionStatus" begin
        struct another_test_sc <: DS.AbstractStoppingCondition end
        DS.CheckStoppingCondition(p::DSProblem, s::another_test_sc) = false

        @test DS.StoppingConditionStatus(another_test_sc()) == "Unknown stopping condition status"
        p = DSProblem(4)
        DS.AddStoppingCondition(p, another_test_sc())
        DS.CheckStoppingConditions(p)
        @test p.status.optimization_status == "Unknown stopping condition status"
    end

end
